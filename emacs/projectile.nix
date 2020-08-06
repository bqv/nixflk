{ config, lib, usr, pkgs, ... }:

{
  emacs-loader.projectile = {
    demand = true;
    diminish = [ "projectile-mode" ];
    config = ''
      (setq projectile-completion-system 'ivy)
      (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
      (setq projectile-enable-caching t)
      (projectile-mode t)
      (setq compilation-buffer-name-function
            (lambda (mode)
              (concat "*" (downcase mode) ": " (projectile-project-name) "*")))
    '';
  };
}
