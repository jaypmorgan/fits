;;;; fits.asd

(asdf:defsystem #:fits
  :description "Input/Output for fits file format"
  :author "Jay Morgan <jay.morgan@univ-tln.fr>"
  :license  "Specify license here"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-ppcre #:array-operations)
  :components ((:file "package")
               (:file "fits")))
