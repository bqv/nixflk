{ config, lib, pkgs, ... }:

with lib; let
  cfg = config.programs.xonsh;

  aliases = rec {
    bat = "${pkgs.bat}/bin/bat --terminal-width -5";
    less = ''${bat} --paging=always --pager "${pkgs.less}/bin/less -RF"'';
    ls = "${pkgs.exa}/bin/exa";
    procs = "${pkgs.procs}/bin/procs";
    diff = "${pkgs.colordiff}/bin/colordiff";
    tmux = "tmux -2"; # Force 256 colors
    jq = "jq -C"; # Force colors
    rg = "rg --color always"; # Force color
    #bw = "env $(cat ~/.bwrc) bw";
    nix-build = "echo disabled: nix-build"; # require nix-command
    nix-channel = "echo disabled: nix-channel"; # require nix-command
    nix-copy-closure = "echo disabled: nix-copy-closure"; # require nix-command
    nix-env = "echo disabled: nix-env"; # require nix-command
    nix-hash = "echo disabled: nix-hash"; # require nix-command
    nix-instantiate = "echo disabled: nix-instantiate"; # require nix-command
    nix-store = "echo disabled: nix-store"; # require nix-command
    nix-shell = "echo disabled: nix-shell"; # require nix-command
    sudo = pkgs.writeShellScript "sudo-discouraged" ''
      echo warning: "sudo $@" should be "doas $@" >&2
      exec sudo $@
    ''; # discourage sudo
  };

  abbrevs = rec {
    gl = "git log --oneline --all --graph";
    gf = "git fetch --all --prune --tags";
    gc = "git commit -m ! ";
    gca = "git commit --amend";
    gcan = "git commit --amend --no-edit";

    sstart = "doas systemctl start";
    sstop = "doas systemctl stop";
    srestart = "doas systemctl restart";
    sstatus = "doas systemctl status";
    senable = "doas systemctl enable";
    sdisable = "doas systemctl disable";
    smask = "doas systemctl mask";
    sunmask = "doas systemctl unmask";
    sreload = "doas systemctl daemon-reload";

    ustart = "systemctl start --user";
    ustop = "systemctl stop --user";
    urestart = "systemctl restart --user";
    ustatus = "systemctl status --user";
    uenable = "systemctl enable --user";
    udisable = "systemctl disable --user";
    ureload = "systemctl daemon-reload --user";
  };

  functions = {
    exwm-exec = '' emacsclient --eval '(bqv/exwm-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
    exwm-sudo-exec = '' emacsclient --eval '(bqv/exwm-sudo-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
    exwm-nix-exec = '' emacsclient --eval '(bqv/exwm-nix-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
    find-file = '' emacsclient --eval '(find-file "'"$argv"'")' '';
    please = '' eval doas $history[1] '';
    vterm-printf = ''
      if [ -n "$TMUX" ]
          # tell tmux to pass the escape sequences through
          # (Source: http://permalink.gmane.org/gmane.comp.terminal-emulators.tmux.user/1324)
          printf "\ePtmux;\e\e]%s\007\e\\" "$argv"
      else if string match -q -- "screen*" "$TERM"
          # GNU screen (screen, screen-256color, screen-256color-bce)
          printf "\eP\e]%s\007\e\\" "$argv"
      else
          printf "\e]%s\e\\" "$argv"
      end
    '';
    "track_directories --on-event fish_prompt" = ''
      vterm-printf '51;A'(whoami)'@'(hostname)':'(pwd);
    '';
    vterm-cmd = ''
      if [ -n "$TMUX" ]
          printf "\ePtmux;\e\e]"
      else if string match -q -- "screen*" "$TERM"
          printf "\eP\e]"
      else
          printf "\e]"
      end
      while [ (count $argv) -gt 0 ];
          printf '"%s" ' (string replace -a '"' '\\"' (string replace -a '\\' '\\\\' $argv[1]))
          shift
      end
      if [ -n "$TMUX" ]
          printf "\007\e\\"
      else if string match -q -- "screen*" "$TERM"
          printf "\007\e\\"
      else
          printf "\e\\"
      end
    '';
  };
in {
  options.programs.xonsh.enable = lib.mkEnableOption "the xonsh shell";

  config = mkIf cfg.enable {
    home.file.".colordiffrc" = {
      source = "${pkgs.colordiff}/etc/colordiffrc";
    };

    home.file.".config/xonsh/rc.xsh" = {
      text = ''
        $AUTO_CD = True
        # $XONSH_SHOW_TRACEBACK = True
        $COLOR_RESULTS = True
        $COMPLETIONS_BRACKETS = True
        $XONSH_HISTORY_SIZE = "65536 commands"
        $XONSH_STORE_STDOUT = True
        __xonsh__.env['XONTRIB_OUTPUT_SEARCH_KEY'] = 'i'

        xontrib load abbrevs
        xontrib load bashisms
        xontrib load direnv
        xontrib load fzf-widgets
        xontrib load histcpy
        xontrib load jedi
        xontrib load output_search
        xontrib load readable-traceback
        xontrib load schedule
        xontrib load z

        from prompt_toolkit.keys import Keys
        $fzf_history_binding = Keys.ControlR
        $fzf_ssh_binding = Keys.ControlS
        $fzf_file_binding = Keys.ControlT

        ${lib.concatStrings (lib.mapAttrsToList (k: v: with lib.strings; ''
          aliases[${escapeNixString k}] = ${escapeNixString v}
        '') aliases)}

        ${lib.concatStrings (lib.mapAttrsToList (k: v: with lib.strings; ''
          abbrevs[${escapeNixString k}] = ${escapeNixString v}
        '') abbrevs)}

        def _emacs_vterm_prompt_hook():
          if "INSIDE_EMACS" in ''${...}:
            print("\x1b]51;A{user}@{host}:{cwd}\x1b\\".format(
              user = $(whoami).strip(),
              host = $(hostname).strip(),
              cwd = $(pwd).strip()))

        if ''${...}.get("INSIDE_EMACS") == "vterm":
          "DVTM" not in ''${...} && exec env TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -Al emacs ${pkgs.dvtm}/bin/dvtm -m '^q'
        elif "EMACS" not in ''${...}:
          if ''${...}.get("TERM") == "dumb":
            exec bash
          elif "DISPLAY" in ''${...}:        # If we're in X11
            "DVTM" not in ''${...} && exec env TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -Al main ${pkgs.dvtm}/bin/dvtm -m '^q'
          elif "/dev/tty" in $(tty):         # If we're in TTY
            "TMUX" not in ''${...} && exec ${pkgs.tmux}/bin/tmux new -A -s @($(echo X$DISPLAY | sed 's/X:/X/;s/:/-/').strip())
          elif "SSH_CONNECTION" in ''${...}: # If we're in SSH
            if "MOBILE" in ''${...}:         # If we're on mobile
              "DVTM" not in ''${...} && exec env -u MOBILE TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -A  main ${pkgs.dvtm}/bin/dvtm -m '^q'
            else:
              "DVTM" not in ''${...} && exec env           TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -Al main ${pkgs.dvtm}/bin/dvtm -m '^q'
          else:
            abduco -l
            #read -n
        else:
          ''${...}["LC_ALL"] = 'en_GB'
          ''${...}["LANG"] = 'en_GB'
          ''${...}["LC_CTYPE"] = 'C'
          ''${...}["SHELL"] = "emacs "+''${...}.get("EMACS")
          ''${...}["TERM"] = "emacs "+''${...}.get("EMACS")

        if "DISPLAY" not in ''${...}:
          ''${...}["GPG_TTY"] = $(tty).strip()
        ''${...}["SSH_AUTH_SOCK"] = $(gpgconf --list-dirs agent-ssh-socket).strip()

        xontrib load powerline
        date

        ${pkgs.fortune}/bin/fortune -as linux linuxcookie paradoxum computers science definitions | tee -a /tmp/fortune.log | ${pkgs.cowsay}/bin/cowsay
        echo -e '\n' >> /tmp/fortune.log
      '';
    };
  };
}
