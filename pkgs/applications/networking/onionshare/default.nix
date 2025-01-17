{ lib
, stdenv
, buildPythonApplication
, cepa
, colorama
, fetchFromGitHub
, flask
, flask-compress
, flask-httpauth
, flask-socketio
, gevent-socketio
, gevent-websocket
, obfs4
, psutil
, pycrypto
, pynacl
, pyqt5
, pyside6
, pysocks
, pytestCheckHook
, qrcode
, qt5
, requests
, snowflake
, substituteAll
, tor
, unidecode
, waitress
}:

let
  version = "2.6.1";
  src = fetchFromGitHub {
    owner = "onionshare";
    repo = "onionshare";
    rev = "v${version}";
    sha256 = "sha256-LR3Ao4Q8kEDwrFV+gYdMSEeYF4hDtEa1rJgvRRrJMwc=";
  };
  meta = with lib; {
    description = "Securely and anonymously send and receive files";
    longDescription = ''
      OnionShare is an open source tool for securely and anonymously sending
      and receiving files using Tor onion services. It works by starting a web
      server directly on your computer and making it accessible as an
      unguessable Tor web address that others can load in Tor Browser to
      download files from you, or upload files to you. It doesn't require
      setting up a separate server, using a third party file-sharing service,
      or even logging into an account.

      Unlike services like email, Google Drive, DropBox, WeTransfer, or nearly
      any other way people typically send files to each other, when you use
      OnionShare you don't give any companies access to the files that you're
      sharing. So long as you share the unguessable web address in a secure way
      (like pasting it in an encrypted messaging app), no one but you and the
      person you're sharing with can access the files.
    '';

    homepage = "https://onionshare.org/";

    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ bbjubjub ];
    mainProgram = "onionshare-cli";
  };

  # TODO: package meek https://support.torproject.org/glossary/meek/
  meek = "/meek-not-available";

in
rec {
  onionshare = buildPythonApplication {
    pname = "onionshare-cli";
    inherit version meta;
    src = "${src}/cli";
    patches = [
      # hardcode store paths of dependencies
      (substituteAll {
        src = ./fix-paths.patch;
        inherit tor meek obfs4 snowflake;
        inherit (tor) geoip;
      })
    ];
    propagatedBuildInputs = [
      cepa
      colorama
      flask
      flask-compress
      flask-httpauth
      flask-socketio
      gevent-socketio
      gevent-websocket
      psutil
      pycrypto
      pynacl
      pyside6
      qrcode
      requests
      unidecode
      waitress
    ];

    buildInputs = [
      obfs4
      tor
    ];

    nativeCheckInputs = [
      pytestCheckHook
    ];

    preCheck = ''
      # Tests use the home directory
      export HOME="$(mktemp -d)"
    '';

    disabledTests = lib.optionals stdenv.isLinux [
      "test_get_tor_paths_linux"  # expects /usr instead of /nix/store
    ] ++ lib.optionals stdenv.isDarwin [
      # requires meek-client which is not packaged
      "test_get_tor_paths_darwin"
      # on darwin (and only on darwin) onionshare attempts to discover
      # user's *real* homedir via /etc/passwd, making it more painful
      # to fake
      "test_receive_mode_webhook"
    ];
  };

  onionshare-gui = buildPythonApplication {
    pname = "onionshare";
    inherit version meta;
    src = "${src}/desktop";
    patches = [
      # hardcode store paths of dependencies
      (substituteAll {
        src = ./fix-paths-gui.patch;
        inherit tor meek obfs4 snowflake;
        inherit (tor) geoip;
      })
    ];

    propagatedBuildInputs = [
      onionshare
      psutil
      pyqt5
      pyside6
      pysocks
      qrcode
    ];

    nativeBuildInputs = [ qt5.wrapQtAppsHook ];

    postInstall = ''
      mkdir -p $out/share/{appdata,applications,icons}
      cp $src/org.onionshare.OnionShare.desktop $out/share/applications
      cp $src/org.onionshare.OnionShare.svg $out/share/icons
      cp $src/org.onionshare.OnionShare.appdata.xml $out/share/appdata
    '';

    preFixup = ''
      wrapQtApp $out/bin/onionshare
    '';

    doCheck = false;

    pythonImportsCheck = [ "onionshare" ];
  };
}
