{ mkShell
, electron_41
, git
, git-lfs
, imagemagick
, jq
, nodejs_22
, pkg-config
, python3
, ripgrep
}:

mkShell {
  packages = [
    electron_41
    git
    git-lfs
    imagemagick
    jq
    nodejs_22
    pkg-config
    python3
    ripgrep
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };
}
