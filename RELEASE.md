# Releasing Spread++

Spread++ releases use a date-based version in `YYYY.MM.DD` format. Additional
releases on the same UTC day append a positive sequence number, producing
`YYYY.MM.DD.1`, `YYYY.MM.DD.2`, and so on. Publishing a GitHub Release triggers
`.github/workflows/release.yaml`, which builds Linux archives and snaps for amd64
and arm64 and attaches them to the release with checksums.

Releases use the `devel` branch. Release branches start from `devel`, release
pull requests target `devel`, and release tags are created from `devel`.
The repository default branch can remain `main`.

Development binaries built by `.github/workflows/test.yaml` use
`YYYY.MM.DD-dev.SHORT_SHA`. This keeps builds from `main` and `devel` distinct
from published releases and identifies the source commit. CI runs on pushes
and pull requests to both branches. Google Cloud uploads remain restricted to
pushes to `main`.

## Prerequisites

- Write access to the `nulltrek/spread-plus` repository.
- Permission to publish GitHub Releases and run GitHub Actions.

### Automated release prerequisites

The automation requires Bash, Git, Go 1.24 or newer, the GitHub CLI, GNU core
utilities, `tar`, and `sha256sum`. On Ubuntu, install them with:

```shell
sudo apt update
sudo apt install -y git coreutils tar
sudo snap install go --classic --channel=1.24/stable
sudo snap install gh
```

Authenticate the GitHub CLI and verify that it can access the repository:

```shell
gh auth login
gh auth status
gh repo view nulltrek/spread-plus
```

Clone the release repository, or confirm that an existing checkout uses it as
the `origin` remote:

```shell
git clone git@github.com:nulltrek/spread-plus.git
cd spread-plus
git remote get-url origin
```

Before running the automation, verify the required tools and repository state:

```shell
bash --version
git --version
go version
gh --version
sha256sum --version
tar --version
git status --short
```

`go version` must report Go 1.24 or newer, `origin` must point to
`nulltrek/spread-plus`, and `git status --short` must produce no output. Ensure
the script is executable if the checkout did not preserve its mode:

```shell
chmod +x release.sh
```

## Automated release

The `release.sh` script automates the preparation, publication, and verification
steps. Run each command from the repository root. The version is optional and
defaults to the current UTC date in `YYYY.MM.DD` format. For a second or later
release on the same day, pass `YYYY.MM.DD.N` explicitly, starting with `.1`.

For example:

```shell
./release.sh prepare 2026.09.15.1
```

1. Prepare the release branch and pull request:

   ```shell
   ./release.sh prepare [VERSION]
   ```

   This checks the working tree and release tag, updates `snapcraft.yaml`, runs
   the tests and versioned build, commits the change, pushes the release branch,
   and opens a pull request against `devel`.

2. Wait for the required checks, review the pull request, and merge it. This is
   intentionally not automated.

3. Publish the release from the updated `devel` branch:

   ```shell
   ./release.sh publish [VERSION]
   ```

   This confirms the merged version and creates the GitHub Release. The release
   triggers the `Release Spread++` workflow that builds and uploads assets.

4. After the release workflow succeeds, verify its assets:

   ```shell
   ./release.sh verify [VERSION]
   ```

   This checks that all expected assets exist, downloads them into
   `spreadpp-VERSION`, verifies their checksums, and checks the version of the
   binary for the local architecture.

The commands are separate because a pull request must be reviewed and merged
between preparation and publication, and the release workflow must finish
before verification.

## Manual release

The following steps document the equivalent manual process.

### Prepare the release

1. Choose the release version:

   ```shell
   VERSION="$(date -u +%Y.%m.%d)"
   ```

   For an additional release on the same day, append the next positive sequence
   number:

   ```shell
   VERSION="$(date -u +%Y.%m.%d).1"
   ```

2. Create a branch from the latest `devel`:

   ```shell
   git switch devel
   git pull --ff-only origin devel
   git switch -c "release-${VERSION}"
   ```

3. Set `version` in `snapcraft.yaml` to `${VERSION}`.

4. Run the local checks:

   ```shell
   go test ./...
   go build -ldflags "-X main.version=${VERSION}" -o bin/spreadpp ./cmd/spread
   ./bin/spreadpp --version
   rm bin/spreadpp
   ```

   The version command must print `${VERSION}`.

5. Commit the version update, push the branch, and open a pull request:

   ```shell
   git add snapcraft.yaml
   git commit -m "Prepare ${VERSION} release"
   git push -u origin "release-${VERSION}"
   gh pr create --repo nulltrek/spread-plus --base devel --fill
   ```

6. Wait for all required GitHub Actions checks to pass, review the generated
   changes, and merge the pull request.

### Publish the release

1. Update the local `devel` branch and confirm that the release commit is
   present:

   ```shell
   git switch devel
   git pull --ff-only origin devel
   git status --short
   ```

   The working tree should be clean.

2. Confirm that the version has not already been released:

   ```shell
   git ls-remote --exit-code --tags origin "refs/tags/${VERSION}"
   ```

   This command should return no matching tag and exit with status 2.

3. Publish the GitHub Release:

   ```shell
   gh release create "${VERSION}" \
       --repo nulltrek/spread-plus \
       --target devel \
       --title "Spread++ ${VERSION}" \
       --generate-notes
   ```

   Publishing the release creates the tag and starts the `Release Spread++`
   workflow. Do not create or upload the binary archives manually.

### Verify the release

1. Confirm that the release workflow completed successfully in GitHub Actions.

2. Confirm that the release contains all five generated assets:

   - `spreadpp-amd64.tar.gz`
   - `spreadpp-arm64.tar.gz`
   - `spreadpp-amd64.snap`
   - `spreadpp-arm64.snap`
   - `SHA256SUMS`

3. Download and verify the assets:

   ```shell
   mkdir "spreadpp-${VERSION}"
   cd "spreadpp-${VERSION}"
   gh release download "${VERSION}" --repo nulltrek/spread-plus
   sha256sum --check SHA256SUMS
   ```

4. Extract the archive for the local architecture and check its version:

   ```shell
   tar -xzf "spreadpp-$(dpkg --print-architecture).tar.gz"
   ./spreadpp --version
   ```

   The command must print the release tag exactly.

## Failed releases

If the release workflow fails because of a transient issue, rerun the failed
jobs in GitHub Actions. If the source itself is faulty, fix it through another
pull request and publish a new version. Do not move or reuse a published release
tag.

The GitHub workflow builds and attaches snap files to the GitHub Release. It does
not publish them to the Snap Store; Store publishing remains a separate process.
