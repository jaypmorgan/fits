;;;; fits.lisp

(in-package #:fits)

(defparameter *f* "mK100204.144719.fits")

(defun bytes->string (bytes)
  "Transform a sequence of bytes into a string"
  (format nil "~{~A~}" (mapcar #'code-char bytes)))

(defun single-to-double-quotes (str)
  (cl-ppcre:regex-replace-all "\'(.*?)?\'" str "\"\\1\""))

(defun remove-comments (str)
  (cl-ppcre:regex-replace-all "\/.*" str ""))

(defun remove-trailing-spaces (str)
  (string-trim "= " str))

(defun clean-string (str)
  "Remove comments and trailing spaces"
  (single-to-double-quotes
   (remove-trailing-spaces
    (remove-comments str))))

(defun string->value (str)
  (read-from-string str))

(defun separate-hdr-components (hdr)
  "Compose the head into components"
  (if (not (string= "" hdr))
   (cons (cons (clean-string (subseq hdr 0 8))
	       (clean-string (subseq hdr 8 80)))
	 (separate-hdr-components (subseq hdr 80)))))

(defun parse-header (hdr)
  "Take the header string and compose them into header units"
  (mapcar (lambda (unit) (cons (intern (car unit)) (string->value (cdr unit))))
	  (remove-if
	      (lambda (comp) (or (string= "" (car comp)) (string= "END" (car comp))))
	      (separate-hdr-components (bytes->string hdr)))))

(defun parse-data (filepath)
  (with-open-file (stream filepath :element-type 'unsigned-byte)
    (let ((buf (make-array (file-length stream) :element-type (stream-element-type stream))))
      (read-sequence buf stream)
      buf)))

(defun header-keys (hdu)
  (mapcar #'car hdu))

(defun header-values (hdu)
  (mapcar #'cdr hdu))

(defun key-exists (key keys)
  (position key keys))

(defun pluck-item (key lst)
  (cdr (assoc key lst)))

(defun range (n)
  (loop for i from 1 upto n collect i))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parsing the data
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun n-dims (hdu)
  (let ((keys (header-keys hdu))
	(dims nil))
    (dotimes (i 4)
      (let ((name (intern (format nil "NAXIS~A" (1+ i)))))
	(if (key-exists name keys)
	   (setf dims (cons (pluck-item name hdu) dims))
	   (return-from n-dims dims))))))

(defun int-size (hdu)
  "The size of integer representation in the header"
  (pluck-item 'bitpix hdu))

(defun read-in (in)
  (let ((u2 0))
    (setf (ldb (byte 8 0) u2) (aref in 0))
    (setf (ldb (byte 8 8) u2) (aref in 1))
    u2))

(defun bytes->int (size seq &optional (step (/ size 8)))
  "Convert a stream of bytes into a list of integers"
  (loop for i from 0 below (/ (length seq) step) by step
	collect (read-in (subseq seq i (+ i step)))))

(defun parse-data-block (hdu seq)
  (let* ((dims (n-dims hdu))
	 (nel  (apply #'* dims))
	 (arr  (make-array nel :initial-contents (bytes->int (int-size hdu) seq))))
    (array-operations:reshape arr dims)))

(defstruct smap
  (header)
  (data))

(defun read-fits (filepath)
  (let* ((bits (parse-data filepath))
	 (hdu-end (position (char-code #\Null) bits))
	 (header (parse-header (coerce (subseq bits 0 hdu-end) 'list)))
	 (data (parse-data-block header (subseq bits (1+ hdu-end)))))
    (make-smap :header header :data data)))
