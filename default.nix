{}:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

let
  inherit (builtins) concatMap getEnv toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
  inherit (lib.attrsets) collect isDerivation;
  inherit (stdenv) mkDerivation;

  php55DockerArgHints = lib.phpDockerArgHints phpDeprecated.php55;

  rootfs = mkRootfs {
    name = "apache2-rootfs";
    src = ./rootfs;
    inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd
      mjHttpErrorPages postfix s6 execline;
    zendguard = zendguard.loader-php55;
    php55 = phpDeprecated.php55;
    mjperl5Packages = mjperl5lib;
    ioncube = ioncube.v55;
    s6PortableUtils = s6-portable-utils;
    s6LinuxUtils = s6-linux-utils;
    mimeTypes = mime-types;
    libstdcxx = gcc-unwrapped.lib;
  };

in

pkgs.dockerTools.buildLayeredImage rec {
  maxLayers = 3;
  name = "docker-registry.intr/webservices/apache2-php55";
  tag = "latest";
  contents = [
    rootfs
    tzdata
    locale
    postfix
    sh
    coreutils
    libjpeg_turbo
    (optipng.override{ inherit libpng ;})
    gifsicle cacert
    perl
  ] ++ collect isDerivation phpPackages.php55Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php55DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php55DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
    extraCommands = ''
      set -xe
      ls
      mkdir -p etc
      mkdir -p bin
      mkdir -p usr/local
      ln -s /bin usr/bin
      ln -s /bin usr/sbin
      ln -s /bin usr/local/bin
    '';
  };
}
