{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.programs.fish;
in {
  config = mkIf cfg.enable {
    home.file.".colordiffrc" = {
      source = "${pkgs.colordiff}/etc/colordiffrc";
    };
    programs.fish = {
      promptInit = ''
        set fish_prompt_pwd_dir_length 1
        set __fish_git_prompt_show_informative_status 1

        # Fish command and parameter colors
        set fish_color_command green
        set fish_color_param $fish_color_normal

        # Git prompt
        set __fish_git_prompt_showdirtystate 'yes'
        set __fish_git_prompt_showupstream 'yes'

        set __fish_git_prompt_color_branch brown
        set __fish_git_prompt_color_dirtystate FCBC47
        set __fish_git_prompt_color_stagedstate yellow
        set __fish_git_prompt_color_upstream cyan
        set __fish_git_prompt_color_cleanstate green
        set __fish_git_prompt_color_invalidstate red

        # Git Characters
        set __fish_git_prompt_char_dirtystate '*'
        set __fish_git_prompt_char_stateseparator ' '
        set __fish_git_prompt_char_untrackedfiles ' …'
        set __fish_git_prompt_char_cleanstate '✓'
        set __fish_git_prompt_char_stagedstate '⇢ '
        set __fish_git_prompt_char_conflictedstate "✕"

        set __fish_git_prompt_char_upstream_prefix ' '
        set __fish_git_prompt_char_upstream_equal ' '
        set __fish_git_prompt_char_upstream_ahead '⇡'
        set __fish_git_prompt_char_upstream_behind '⇣'
        set __fish_git_prompt_char_upstream_diverged '⇡⇣'

        function _print_in_color
          set -l string $argv[1]
          set -l color  $argv[2]

          set_color $color
          printf $string
          set_color normal
        end

        function _prompt_color_for_status
          if test $argv[1] -eq 0
            echo magenta
          else
            echo red
          end
        end

        function fish_nix_prompt
          set_color blue
          if test -n "$IN_NIX_SHELL"
            echo -n "env:"
            set_color -o red
            set -l git_dir (command git rev-parse --git-common-dir 2>/dev/null)
            if test -n "$git_dir"
              set -l git_desc (command sed -ne 1p "$git_dir/description")
              if test -n "$git_desc"
                echo -n "$git_desc "
              else if test -n "$IN_NIX_SHELL"
                echo -n "nix-shell "
              end
            else if test -n "$IN_NIX_SHELL"
              echo -n "nix-shell "
            end
          end
          set_color normal
        end

        function fish_emacs_vterm_prompt_hook
          if test -n "$INSIDE_EMACS"
            printf "\e]51;A"(whoami)"@"(hostname)":"(pwd)"\e\\"
          end
        end

        function fish_prompt --description 'Write out the prompt'
            set -l color_cwd
            set -l suffix
            switch "$USER"
                case root toor
                    if set -q fish_color_cwd_root
                        set color_cwd $fish_color_cwd_root
                    else
                        set color_cwd $fish_color_cwd
                    end
                    set suffix '#'
                case '*'
                    set color_cwd $fish_color_cwd
                    set suffix '>'
            end

            echo -n -s (fish_emacs_vterm_prompt_hook)
            echo -n -s (fish_nix_prompt)
            echo -n -s "$USER" @ (prompt_hostname) ' ' (set_color $color_cwd) (prompt_pwd) (set_color normal)
            echo -n -s (fish_vcs_prompt)
            echo -n -s "$suffix "
        end
      '';
      interactiveShellInit = ''
        if test "$INSIDE_EMACS" = "vterm"
            test -z "$DVTM"; and exec env TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -Al emacs ${pkgs.dvtm}/bin/dvtm -m '^q'
        else if test -z "$EMACS"
            if test "$TERM" = "dumb"
                exec bash
            else if test -n "$DISPLAY"                # If we're in X11
                test -z "$TMUX"; and exec ${pkgs.tmux}/bin/tmux new -A -s (echo X$DISPLAY | sed 's/X:/X/;s/[.:]/-/')
            else if contains (tty) /dev/tty*          # If we're in TTY
                test -z "$WINDOW"; and exec ${pkgs.screen}/bin/screen -xRR
            else if test -n "$SSH_CONNECTION"         # If we're in SSH
                if test -n "$MOBILE"                  # If we're on mobile
                    test -z "$DVTM"; and exec env -u MOBILE TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -A  main ${pkgs.dvtm}/bin/dvtm -m '^q'
                else
                    test -z "$DVTM"; and exec env           TERM=dvtm-256color ${pkgs.abduco}/bin/abduco -Al main ${pkgs.dvtm}/bin/dvtm -m '^q'
                end
            else
                abduco -l
                #read -n
            end
        else
            set -x LC_ALL 'en_GB'
            set -x LANG 'en_GB'
            set -x LC_CTYPE C
            set -x SHELL "emacs $EMACS"
            set -x TERM "emacs $EMACS"
        end

        if test -z "$DISPLAY"
            export GPG_TTY=(tty)
        end

        date

        ${pkgs.fortune}/bin/fortune -as linux linuxcookie paradoxum computers science definitions |\
          tee -a /tmp/fortune.log |\
          ${pkgs.cowsay}/bin/cowsay
        echo -e '\n' >> /tmp/fortune.log
      '';

      shellAliases = rec {
        bat = "${pkgs.bat}/bin/bat --terminal-width -5";
        cat = "${bat}";
        less = ''${bat} --paging=always --pager "${pkgs.less}/bin/less -RF"'';
        ls = "${pkgs.exa}/bin/exa";
        ps = "${pkgs.procs}/bin/procs";
        diff = "${pkgs.colordiff}/bin/colordiff";
        tmux = "tmux -2"; # Force 256 colors
        jq = "jq -C"; # Force colors
        rg = "rg --color always"; # Force color
        bw = "env (cat ~/.bwrc) bw";

        nix-build = "nix-build --no-out-link";

        sstart = "sudo systemctl start";
        sstop = "sudo systemctl stop";
        srestart = "sudo systemctl restart";
        sstatus = "sudo systemctl status";
        senable = "sudo systemctl enable";
        sdisable = "sudo systemctl disable";
        smask = "sudo systemctl mask";
        sunmask = "sudo systemctl unmask";
        sreload = "sudo systemctl daemon-reload";

        ustart = "systemctl start --user";
        ustop = "systemctl stop --user";
        urestart = "systemctl restart --user";
        ustatus = "systemctl status --user";
        uenable = "systemctl enable --user";
        udisable = "systemctl disable --user";
        ureload = "sudo systemctl daemon-reload --user";
      };

      functions = {
        exwm-exec = '' emacsclient --eval '(bqv/exwm-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
        exwm-sudo-exec = '' emacsclient --eval '(bqv/exwm-sudo-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
        exwm-nix-exec = '' emacsclient --eval '(bqv/exwm-nix-exec "'(which $argv[1])" $argv[2..-1]"'")' '';
        find-file = '' emacsclient --eval '(find-file "'"$argv"'")' '';
        please = '' eval sudo $history[1] '';
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

      plugins = [
        {
          name = "bass";
          src = pkgs.fetchFromGitHub {
            owner = "edc";
            repo = "bass";
            rev = "c0d11420f35cfbcb62f94be0dfcf9baf70a9cea5";
            sha256 = "07x4zvm04kra6cc1224mxm6mdl0gggw0ri98kdgysax53cm8r95r";
          };
        }
      ];
    };
  };
}
