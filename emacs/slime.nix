{ config, lib, usr, pkgs, ... }:

{
  emacs-loader.slime = {
    demand = true;
    config = ''
      (setq slime-auto-connect 'always)
      (setq slime-enable-evaluate-in-emacs t)

      (defun nyxt/repl ()
        (interactive)
        (slime-connect "localhost" 4005 nil (interactive-p)))

      (defun nyxt/push (text)
        (interactive "sText: ")
        (slime-eval `(containers:insert-item (nyxt:clipboard-ring nyxt::*browser*) ,text)))

      (defun nyxt/pull ()
        (interactive)
        (unless (slime-eval '(containers:empty-p (nyxt:clipboard-ring nyxt-user::*browser*)))
          (let ((s (slime-eval '(containers:first-item (nyxt:clipboard-ring nyxt-user::*browser*)))))
            (when s
              (kill-new s)))))

      (defun nyxt/select-uri ()
        (interactive)
        (let* ((uris (slime-eval
                      (quote
                       (cl:mapcar
                        (cl:lambda (buffer) (quri:render-uri (nyxt:url buffer)))
                        (nyxt:buffer-list))
                       )))
               (uri (completing-read "Nyxt URIs: " uris)))
          (kill-new uri)
          (message "Copied: %s" uri)))
    '';
  };
}
