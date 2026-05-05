name: CD Build Multiarch OpenSSL+Quic BuildEnv Docker Image

on:
  workflow_run:
    workflows: ["cd-build-openssl-buildenv"]
    types:
      - completed
  workflow_dispatch:

env:
  DOCKERHUB_SLUG: "madnuttah/openssl-buildenv"

jobs:
  detect_versions:
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    runs-on: ubuntu-latest
    outputs:
      OPENSSL_BUILDENV_VERSION: ${{ steps.detect.outputs.OPENSSL_BUILDENV_VERSION }}
      TAG_VERSION: ${{ steps.detect.outputs.TAG_VERSION }}

    steps:
      - name: Fetch buildvars
        id: detect
        run: |
          curl -s -L https://raw.githubusercontent.com/madnuttah/openssl-buildenv/main/buildvars -o buildvars

          OPENSSL_BUILDENV_VERSION=$(grep '^OPENSSL_BUILDENV_VERSION=' buildvars | cut -d '=' -f2-)

          echo "OPENSSL_BUILDENV_VERSION=$OPENSSL_BUILDENV_VERSION" >> $GITHUB_OUTPUT
          echo "TAG_VERSION=${OPENSSL_BUILDENV_VERSION}-quic" >> $GITHUB_OUTPUT


  build_multiarch:
    needs: detect_versions
    runs-on: ubuntu-latest
    if: ${{ needs.detect_versions.outputs.TAG_VERSION != '' }}

    steps:
      - uses: actions/checkout@v6

      - uses: docker/setup-qemu-action@v4
      - uses: docker/setup-buildx-action@v4

      - uses: docker/login-action@v4
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push multiarch QUIC addon
        uses: docker/build-push-action@v7
        with:
          platforms: linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/386
          file: ./openssl+quic/Dockerfile
          push: true
          build-args: |
            OPENSSL_BUILDENV_VERSION=${{ needs.detect_versions.outputs.OPENSSL_BUILDENV_VERSION }}
          tags: |
            ${{ env.DOCKERHUB_SLUG }}:${{ needs.detect_versions.outputs.TAG_VERSION }}


  finalize:
    needs: [detect_versions, build_multiarch]
    runs-on: ubuntu-latest
    steps:
      - name: Done
        run: echo "Multiarch QUIC build completed."
