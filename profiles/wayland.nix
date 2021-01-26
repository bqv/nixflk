{ config, pkgs, lib, ... }:

{
  config = {
    environment.systemPackages = with pkgs; with velox; [
      dmenu (pkgs.lowPrio dmenu-velox)
      st-velox
    ];

    environment.etc = {
      "velox.conf".source = "${pkgs.velox}/etc/velox.conf";
      "greetd/config.toml".text = let
        swcd = with config.services.swc-launch; pkgs.writeShellScript "wayland-session" ''
          export XKB_DEFAULT_LAYOUT="${layout}";
          export XKB_DEFAULT_OPTIONS="${xkbOptions}";

          # FIXME: This doesn't work when the user hasn't explicitly set her uid.
          export XDG_RUNTIME_DIR="/run/user/${toString config.users.extraUsers.${user}.uid}";
          export XDG_SESSION_TYPE=wayland

          export MOZ_ENABLE_WAYLAND=1
          export CLUTTER_BACKEND=wayland
          export QT_QPA_PLATFORM=wayland-egl
          export ECORE_EVAS_ENGINE=wayland-egl
          export ELM_ENGINE=wayland_egl
          export SDL_VIDEODRIVER=wayland
          export _JAVA_AWT_WM_NONREPARENTING=1
          export NO_AT_BRIDGE=1

          exec ${config.security.wrapperDir}/swc-launch -t /dev/tty${toString tty} \
            -- ${server.${server.active_server}.command}
        '';
      in ''
        [terminal]
        vt = 1

        [default_session]
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${swcd}"
        user = "${config.users.users.greeter.name}"

        [initial_session]
        command = "${swcd}"
        user = "${config.users.users.bao.name}"
      '';
    };

    security.pam.services.greetd = {
      allowNullPassword = true;
      startSession = true;
    };

    # Enable swc+velox (Wayland compositor) as alternative to X11
    services.swc-launch = {
      enable = true;
      user = "bao";
      layout = "gb";
      xkbOptions = "caps:ctrl_modifier";
      server.velox.enable = true;
      tty = 9;
    };
    systemd.services.swc-launch = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };

    systemd.services."autovt@tty1".enable = lib.mkForce false;
    systemd.services."getty@tty1".enable = lib.mkForce false;
    systemd.services.display-manager = lib.mkForce {
      enable = true;

      unitConfig = lib.mkForce {
        Wants = [
          "systemd-user-sessions.service"
        ];
        After = [
          "systemd-user-sessions.service"
          "plymouth-quit-wait.service"
          "getty@tty1.service"
        ];
        Conflicts = [
          "getty@tty1.service"
        ];
      };

      serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.greetd}/bin/greetd";

        IgnoreSIGPIPE = "no";
        SendSIGHUP = "yes";
        TimeoutStopSec = "30s";
        KeyringMode = "shared";

        # Wayland is way faster to start up
        StartLimitBurst = lib.mkForce "5";
      };

      startLimitIntervalSec = 30;
      restartTriggers = lib.mkForce [];
      restartIfChanged = false;
      stopIfChanged = false;
      aliases = [ "greetd.service" ];
      wantedBy = [ "graphical.target" ];
    };

    users.users.greeter.isSystemUser = true;

    systemd.services.x11 = let cfg = config.services.xserver; in
      { description = "X11 Server";

        wants = [ "systemd-logind.service" ];
        after = [ "acpid.service" "systemd-logind.service" ];
        before = [ "greetd.service" ];
        wantedBy = [ "graphical.target" ];

        restartTriggers = lib.mkForce [];
        restartIfChanged = false;
        stopIfChanged = false;

        environment =
          lib.optionalAttrs config.hardware.opengl.setLdLibraryPath
            { LD_LIBRARY_PATH = pkgs.addOpenGLRunpath.driverLink; }
          // cfg.displayManager.job.environment;

        preStart =
          ''
            ${cfg.displayManager.job.preStart}

            rm -f /tmp/.X0-lock
          '';

        script = "${cfg.displayManager.job.execCmd}";

        # Stop restarting if the display manager stops (crashes) 2 times
        # in one minute. Starting X typically takes 3-4s.
        startLimitIntervalSec = 30;
        startLimitBurst = 3;
        serviceConfig = {
          Restart = "always";
          RestartSec = "200ms";
          SyslogIdentifier = "xserver";
          StartLimitBurst = lib.mkForce "5";
        };
      };
  };
}
