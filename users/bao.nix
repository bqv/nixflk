{ config, pkgs, lib, usr, flake, ... }:

{
  imports = [
    ../profiles/develop
  ];

  environment.variables = {
    GITHUB_TOKEN = usr.secrets.git.github.oauth-token;
  };

  services.dbus.packages = with pkgs; [ gnome3.dconf ];

  services.xinetd = let
    profile = config.users.users.bao;
  in {
    enable = false;
    services = [{
      name = "telnet";
      port = 23;
      protocol = "tcp";
      server = "${pkgs.telnet}/libexec/telnetd";
      serverArgs = let
        shell = pkgs.writeShellScript "run-emacsclient" ''
          exec ${pkgs.emacs}/bin/emacsclient -f ${profile.home}/.emacs.d/server/server -t
        '';
      in '' --exec-login="${shell}" '';
      user = profile.name;
    }];
  };

  users.users.bao = {
    uid = 1000;
    group = "users";
    shell = pkgs.xonsh;
    isNormalUser = true;
    extraGroups = [
      "wheel" "audio" "video" "tty"
      "adbusers" "dwarffs" "audit"
      "ipfs" "syncthing" "aria2"
    ];
  } // usr.secrets.user.password
    // usr.secrets.user.description;

  home-manager.users.bao = let
    home-config = config.home-manager.users.bao;
  in {
    imports = [
      ./shells/fish
      ./shells/xonsh
      ./browsers/firefox
      ./browsers/nyxt
      ./company/locationextreme
      ./editors/emacs
      ./editors/vim
      ./media/gpodder
      ./media/spotify
      ./media/radio
      ./media/mpv
      ./media/aria2
      ./utilities/ssh
      ./utilities/git
      ./utilities/darcs
      ./utilities/htop
      ./services/gnupg
      ./services/velox
      ./services/mpd
      ./services/ckb
      ../guix
    ];

    home.file.".bashrc".text = ''
      # If not running interactively, don't do anything
      [[ $- != *i* ]] && return

      source /etc/profile

      [[ $INSIDE_EMACS == "vterm" ]] && [[ $IN_NIX_SHELL == "" ]] && exec xonsh

      PS1='[\u@\h \W]\$ '

      PS1="\n\[\e[1;30m\][''$$:$PPID - \j:\!\[\e[1;30m\]]\[\e[0;36m\] \T \[\e[1;30m\][\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\]''${SSH_TTY:-o} \[\e[0;32m\]+''${SHLVL}\[\e[1;30m\]] \[\e[1;37m\]\w\[\e[0;37m\] \n\$ "
    '';
    home.file.".profile".text = ''
    '';
    home.file.".config/nixpkgs/config.nix".text = ''
      {
        ${lib.optionalString config.nixpkgs.config.allowUnfree "allowUnfree = true;"}
      }
    '';
    home.file.".gdbinit".source = pkgs.writeText "gdbinit" ''set auto-load safe-path /nix/store'';

    programs.home-manager.enable = true;
    programs.command-not-found.enable = false;
    programs.qutebrowser.enable = true;
    programs.firefox.enable = true;
    programs.xonsh.enable = true;
    programs.fish.enable = true;
    programs.htop.enable = true;
    programs.bat.enable = true;
    programs.fzf.enable = true;
    programs.tmux.enable = true;
    programs.emacs.enable = true;
    programs.neovim.enable = true;
    programs.jq.enable = true;
    programs.direnv.enable = true;
    programs.texlive.enable = true;
    programs.texlive.extraPackages = tpkgs: {
      inherit (tpkgs) collection-basic;
      inherit (tpkgs) collection-latex;
      inherit (tpkgs) collection-latexrecommended;
      inherit (tpkgs) collection-latexextra;
      inherit (tpkgs) collection-luatex;
      inherit (tpkgs) collection-fontsrecommended;
      inherit (tpkgs) collection-fontsextra;
    };
    programs.taskwarrior.enable = true;
    programs.neomutt.enable = true;
    programs.obs-studio.enable = true;
    programs.gpodder.enable = true;
    programs.mpv.enable = true;
    programs.feh.enable = true;
    programs.git.enable = true;
    programs.ssh.enable = true;
    programs.aria2p.enable = true;

    services.lorri.enable = true;
    services.gpg-agent.enable = true;
    services.spotifyd.enable = false;
    services.mpd.enable = true;
    services.mpdris2.enable = true;
    services.taskwarrior-sync.enable = false;
    services.dunst.enable = true;
    services.emacs.enable = true;
    services.pulseeffects.enable = true;
    services.ckb.enable = !config.headless;

    #systemd.user.startServices = true; # broken by the [nix-env -> nix profile] move

    home.packages = with pkgs; let
      twitch = pkgs.writeScriptBin "twitch" ''
        #!${pkgs.execline}/bin/execlineb -S1
        ${pkgs.mpv}/bin/mpv https://twitch.tv/$@
      '';
      emms-play-file = pkgs.writeScriptBin "emms-play-file" ''
        #!${pkgs.execline}/bin/execlineb -W
        ${home-config.programs.emacs.package}/bin/emacsclient --eval "(emms-play-file \"$@\")"
      '';
    in [
      appimage-run steam-run manix # Package Tools
      abduco dvtm # Terminal Multiplexing
      yadm # Dotfile Management
      pstree bottom # Process Monitoring
      pv pup # Pipe Management
      timewarrior # Time Management
      nmap wget curl aria2 httping #mitmproxy # Network Utilities
      ipfscat onionshare nyxt tuir gomuks # Communication Tools
      bitwarden-cli protonvpn-cli # Password Management
      file exa unrar unzip ncdu tree mimeo sqlite # File Management
      audacity twitch streamlink streamlink-twitch-gui-bin # Audio/Video Utilities
      xpra xsel xclip scrot gnome3.zenity # X11 Utilities
      gdb lldb radare2 radare2-cutter jadx stress # Debug Utilities
    ] ++ lib.optional home-config.programs.emacs.enable emms-play-file;

    home.activation.preloadNixSearch = let
      inherit (home-config.home) username;
    in home-config.lib.dag.entryAnywhere ''
      function preloadNixSearch() {
        env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString config.users.users.${username}.uid}/bus \
          systemd-run --user -G --no-block nix search self ""
      }

      preloadNixSearch || true
    '';

    xdg = let
      inherit (home-config.home) homeDirectory;
    in rec {
      enable = true;

      cacheHome = "${homeDirectory}/.cache";
      configHome = "${homeDirectory}/.config";
      dataHome = "${homeDirectory}/.local/share";

      userDirs = {
        enable = true;

        desktop = "${dataHome}/desktop";
        documents = "${homeDirectory}/doc";
        download = "${homeDirectory}/tmp";
        music = "${homeDirectory}/var/music";
        pictures = "${homeDirectory}/var/images";
        publicShare = "${homeDirectory}/var/share";
        templates = "${configHome}/templates";
        videos = "${homeDirectory}/var/videos";
      };

      mimeApps = let
        nyxt = "nyxt.desktop";
        vivaldi = "vivaldi-stable.desktop";
       #qutebrowser = "org.qutebrowser.qutebrowser.desktop";
       #firefox = "firefox.desktop";
        thunderbird = "thunderbird.desktop";

        defaultBrowser = nyxt;
        defaultMailer = thunderbird;
      in {
        enable = true;

        defaultApplications."text/html" = defaultBrowser;
        defaultApplications."x-scheme-handler/http" = defaultBrowser;
        defaultApplications."x-scheme-handler/https" = defaultBrowser;
        defaultApplications."x-scheme-handler/ftp" = defaultBrowser;
        defaultApplications."x-scheme-handler/chrome" = defaultBrowser;
        defaultApplications."application/x-extension-htm" = defaultBrowser;
        defaultApplications."application/x-extension-html" = defaultBrowser;
        defaultApplications."application/x-extension-shtml" = defaultBrowser;
        defaultApplications."application/xhtml+xml" = defaultBrowser;
        defaultApplications."application/x-extension-xhtml" = defaultBrowser;
        defaultApplications."application/x-extension-xht" = defaultBrowser;

        defaultApplications."x-scheme-handler/about" = defaultBrowser;
        defaultApplications."x-scheme-handler/unknown" = defaultBrowser;

        defaultApplications."x-scheme-handler/mailto" = defaultMailer;
        defaultApplications."x-scheme-handler/news" = defaultMailer;
        defaultApplications."x-scheme-handler/snews" = defaultMailer;
        defaultApplications."x-scheme-handler/nntp" = defaultMailer;
        defaultApplications."x-scheme-handler/feed" = defaultMailer;
        defaultApplications."message/rfc822" = defaultMailer;
        defaultApplications."application/rss+xml" = defaultMailer;
        defaultApplications."application/x-extension-rss" = defaultMailer;

        associations.added."x-scheme-handler/http" = [ defaultBrowser ];
        associations.added."x-scheme-handler/https" = [ defaultBrowser ];
        associations.added."x-scheme-handler/ftp" = [ defaultBrowser ];
        associations.added."x-scheme-handler/chrome" = [ defaultBrowser ];
        associations.added."text/html" = [ defaultBrowser ];
        associations.added."application/xhtml+xml" = [ defaultBrowser ];
        associations.added."application/x-extension-htm" = [ defaultBrowser ];
        associations.added."application/x-extension-html" = [ defaultBrowser ];
        associations.added."application/x-extension-shtml" = [ defaultBrowser ];
        associations.added."application/x-extension-xhtml" = [ defaultBrowser ];
        associations.added."application/x-extension-xht" = [ defaultBrowser ];

        associations.added."x-scheme-handler/mailto" = [ defaultMailer ];
        associations.added."x-scheme-handler/news" = [ defaultMailer ];
        associations.added."x-scheme-handler/snews" = [ defaultMailer ];
        associations.added."x-scheme-handler/nntp" = [ defaultMailer ];
        associations.added."x-scheme-handler/feed" = [ defaultMailer ];
        associations.added."message/rfc822" = [ defaultMailer ];
        associations.added."application/rss+xml" = [ defaultMailer ];
        associations.added."application/x-extension-rss" = [ defaultMailer ];
      };
      configFile."mimeapps.list".force = lib.mkForce true;
    };

    gtk = {
      enable = true;
      font = {
        name = "Roboto 9.75";
        package = pkgs.roboto;
      };
      iconTheme = {
        name = "Paper";
        package = pkgs.paper-icon-theme;
      };
      theme = {
        name = "Plata-Noir";
        package = pkgs.plata-theme;
      };
      gtk2.extraConfig = ''
        gtk-cursor-blink = 0
        gtk-im-module = "xim"
        gtk-key-theme-name = "Emacs"
      '';
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-cursor-blink = false;
        gtk-im-module = "xim";
        gtk-key-theme-name = "Emacs";
      };
    };

    qt = {
      enable = true;
      platformTheme = "gnome";
    };
  };
}
