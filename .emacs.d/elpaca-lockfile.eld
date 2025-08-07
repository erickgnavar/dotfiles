((annalist :source "elpaca-menu-lock-file" :recipe
	   (:package "annalist" :fetcher github :repo
		     "noctuid/annalist.el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "e1ef5dad75fa502d761f70d9ddf1aeb1c423f41d"))
 (anything :source "elpaca-menu-lock-file" :recipe
	   (:source "elpaca-menu-lock-file" :protocol https :inherit t
		    :depth treeless :repo
		    "https://repo.or.cz/anything-config.git" :package
		    "anything" :ref
		    "9e2259fc779eef1a3e947e74cc7d301d1cea0ca6"))
 (async :source "elpaca-menu-lock-file" :recipe
	(:package "async" :repo "jwiegley/emacs-async" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "b99658e831bc7e7d20ed4bb0a85bdb5c7dd74142"))
 (auctex :source "elpaca-menu-lock-file" :recipe
	 (:package "auctex" :repo
		   ("https://git.savannah.gnu.org/git/auctex.git"
		    . "auctex")
		   :branch "main" :files ("*" (:exclude ".git"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "2b2b91de473c1501692652c7e9a802f103b82ab7"))
 (avy :source "elpaca-menu-lock-file" :recipe
      (:package "avy" :repo "abo-abo/avy" :fetcher github :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "elpaca-menu-lock-file" :protocol https
		:inherit t :depth treeless :ref
		"933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (caml :source "elpaca-menu-lock-file" :recipe
       (:package "caml" :repo "ocaml/caml-mode" :fetcher github :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "elpaca-menu-lock-file" :protocol https
		 :inherit t :depth treeless :ref
		 "47defafa2b08fb680e89bfee9cb9ce82bd9e3bcf"))
 (cider :source "elpaca-menu-lock-file" :recipe
	(:package "cider" :fetcher github :repo "clojure-emacs/cider"
		  :files
		  ("lisp/*.el" "bin/*.sh" "*.el" "clojure.sh"
		   "lein.sh" (:exclude ".dir-locals.el"))
		  :old-names (nrepl) :source "elpaca-menu-lock-file"
		  :protocol https :inherit t :depth treeless :ref
		  "eb78711b7fb0cb89a9eb1b854aabb174b705f7b2"))
 (clj-refactor :source "elpaca-menu-lock-file" :recipe
	       (:package "clj-refactor" :fetcher github :repo
			 "clojure-emacs/clj-refactor.el" :files
			 (:defaults "CHANGELOG.md") :source
			 "elpaca-menu-lock-file" :protocol https
			 :inherit t :depth treeless :ref
			 "dc1bbc8cdaa723bdbb6669ea7d280625c370755d"))
 (cloak-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "cloak-mode" :fetcher github :repo
		       "erickgnavar/cloak-mode" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "ca0896dfd0a0ee549150233ebd96aa0f65b56afb"))
 (clojure-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "clojure-mode" :repo
			 "clojure-emacs/clojure-mode" :fetcher github
			 :files ("clojure-mode.el") :source
			 "elpaca-menu-lock-file" :protocol https
			 :inherit t :depth treeless :ref
			 "eabe29b076fff19db552d36d4babaa36ecf0b704"))
 (closql :source "elpaca-menu-lock-file" :recipe
	 (:package "closql" :fetcher github :repo "magit/closql"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "d925b8c9c1c724b49d7af7806b7ec1d71209d6e3"))
 (color-theme-sanityinc-tomorrow :source "elpaca-menu-lock-file"
				 :recipe
				 (:package
				  "color-theme-sanityinc-tomorrow"
				  :repo
				  "purcell/color-theme-sanityinc-tomorrow"
				  :fetcher github :files
				  ("*.el" "*.el.in" "dir" "*.info"
				   "*.texi" "*.texinfo" "doc/dir"
				   "doc/*.info" "doc/*.texi"
				   "doc/*.texinfo" "lisp/*.el"
				   "docs/dir" "docs/*.info"
				   "docs/*.texi" "docs/*.texinfo"
				   (:exclude ".dir-locals.el"
					     "test.el" "tests.el"
					     "*-test.el" "*-tests.el"
					     "LICENSE" "README*"
					     "*-pkg.el"))
				  :source "MELPA" :protocol https
				  :inherit t :depth treeless :ref
				  "f3a993da26b3b6f778f5943e095e8b2816a6475c"))
 (combobulate :source "elpaca-menu-lock-file" :recipe
	      (:source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :host github :repo
		       "mickeynp/combobulate" :package "combobulate"
		       :ref "ca2545be196ec32945b5db109578582d7c7270b5"))
 (company :source "elpaca-menu-lock-file" :recipe
	  (:package "company" :fetcher github :repo
		    "company-mode/company-mode" :files
		    (:defaults "icons"
			       ("images/small"
				"doc/images/small/*.png"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "9a81d0cca268d35d5e18d7d4e2277a9e57887dd8"))
 (company-restclient :source "elpaca-menu-lock-file" :recipe
		     (:package "company-restclient" :fetcher github
			       :repo "iquiw/company-restclient" :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "elpaca-menu-lock-file"
			       :protocol https :inherit t :depth
			       treeless :ref
			       "e5a3ec54edb44776738c13e13e34c85b3085277b"))
 (consult :source "elpaca-menu-lock-file" :recipe
	  (:package "consult" :repo "minad/consult" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "c74ae6149172e3429b844c22d67e02b01abea1e4"))
 (consult-yasnippet :source "elpaca-menu-lock-file" :recipe
		    (:package "consult-yasnippet" :fetcher github
			      :repo "mohkale/consult-yasnippet" :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "elpaca-menu-lock-file"
			      :protocol https :inherit t :depth
			      treeless :ref
			      "834d39acfe8a7d2c304afbe4d649b9372118c756"))
 (csv-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "csv-mode" :repo
		     ("https://git.savannah.gnu.org/git/emacs/elpa.git"
		      . "csv-mode")
		     :branch "externals/csv-mode" :files
		     ("*" (:exclude ".git")) :source
		     "elpaca-menu-lock-file" :protocol https :inherit
		     t :depth treeless :ref
		     "849ce3e754f291c3643bc36ed802226606955c3f"))
 (d2-mode :source "elpaca-menu-lock-file" :recipe
	  (:package "d2-mode" :repo "andorsk/d2-mode" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "e1fc7d6c1915acaf476060c0f79b8bdef6bd1952"))
 (dart-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "dart-mode" :fetcher github :repo
		      "emacsorphanage/dart-mode" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "02e919c1cf200b4938139c18068577faff1fb364"))
 (dash :source "elpaca-menu-lock-file" :recipe
       (:package "dash" :fetcher github :repo "magnars/dash.el" :files
		 ("dash.el" "dash.texi") :source
		 "elpaca-menu-lock-file" :protocol https :inherit t
		 :depth treeless :ref
		 "1de9dcb83eacfb162b6d9a118a4770b1281bcd84"))
 (denote :source "elpaca-menu-lock-file" :recipe
	 (:package "denote" :repo
		   ("https://github.com/protesilaos/denote" . "denote")
		   :files
		   ("*" (:exclude ".git" "COPYING" "doclicense.texi"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "212a1b3c17ad99986e593901b3385c9c581b70e4"))
 (diff-hl :source "elpaca-menu-lock-file" :recipe
	  (:package "diff-hl" :fetcher github :repo "dgutov/diff-hl"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "65a5de16e21c87b7c12a78a63fc3b57e07c03c86"))
 (dired-hacks-utils :source "elpaca-menu-lock-file" :recipe
		    (:package "dired-hacks-utils" :fetcher github
			      :repo "Fuco1/dired-hacks" :files
			      ("dired-hacks-utils.el") :source
			      "elpaca-menu-lock-file" :protocol https
			      :inherit t :depth treeless :ref
			      "e9e408e8571aee5574ca0a431ef15cac5a3585d4"))
 (dired-preview :source "elpaca-menu-lock-file" :recipe
		(:package "dired-preview" :repo
			  ("https://github.com/protesilaos/dired-preview"
			   . "dired-preview")
			  :files
			  ("*"
			   (:exclude ".git" "COPYING"
				     "doclicense.texi"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "76e2d2a6675807f41c18c2f000dfaec35ed59100"))
 (dired-subtree :source "elpaca-menu-lock-file" :recipe
		(:package "dired-subtree" :fetcher github :repo
			  "Fuco1/dired-hacks" :files
			  ("dired-subtree.el") :source
			  "elpaca-menu-lock-file" :protocol https
			  :inherit t :depth treeless :ref
			  "e9e408e8571aee5574ca0a431ef15cac5a3585d4"))
 (doom-modeline :source "elpaca-menu-lock-file" :recipe
		(:package "doom-modeline" :repo
			  "seagle0128/doom-modeline" :fetcher github
			  :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "9d6f0f9635ae722b6bd943a76e996f54443e373f"))
 (dumb-jump :source "elpaca-menu-lock-file" :recipe
	    (:package "dumb-jump" :repo "jacktasia/dumb-jump" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "9f3967b0bea038c37d4a6c6bb96144574bb706ee"))
 (edit-indirect :source "elpaca-menu-lock-file" :recipe
		(:package "edit-indirect" :fetcher github :repo
			  "Fanael/edit-indirect" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "82a28d8a85277cfe453af464603ea330eae41c05"))
 (eldoc-box :source "elpaca-menu-lock-file" :recipe
	    (:package "eldoc-box" :repo "casouri/eldoc-box" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "ebc0e2c13791f5a22cf81be050b32f0ebf726855"))
 (elisp-refs :source "elpaca-menu-lock-file" :recipe
	     (:package "elisp-refs" :repo "Wilfred/elisp-refs"
		       :fetcher github :files
		       (:defaults (:exclude "elisp-refs-bench.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "541a064c3ce27867872cf708354a65d83baf2a6d"))
 (ellama :source "elpaca-menu-lock-file" :recipe
	 (:package "ellama" :repo "s-kostyaev/ellama" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "ed530c7f0d7d0aa9916ca73016034829731ddc54"))
 (elm-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "elm-mode" :fetcher github :repo
		     "jcollard/elm-mode" :files (:defaults "elm.tags")
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "699841865e1bd5b7f2077baa7121510b6bcad3c7"))
 (elpaca :source
   "elpaca-menu-lock-file" :recipe
   (:source nil :protocol https :inherit ignore :depth 1 :repo
	    "https://github.com/progfolio/elpaca.git" :ref
	    "f0bbcec414ef7ec7b9ac7caee249dafc0b7c3fd4" :files
	    (:defaults "elpaca-test.el" (:exclude "extensions"))
	    :build (:not elpaca--activate-package) :package "elpaca"))
 (elpaca-use-package :source "elpaca-menu-lock-file" :recipe
		     (:package "elpaca-use-package" :wait t :repo
			       "https://github.com/progfolio/elpaca.git"
			       :files
			       ("extensions/elpaca-use-package.el")
			       :main
			       "extensions/elpaca-use-package.el"
			       :build (:not elpaca--compile-info)
			       :source "elpaca-menu-lock-file"
			       :protocol https :inherit t :depth
			       treeless :ref
			       "f0bbcec414ef7ec7b9ac7caee249dafc0b7c3fd4"))
 (emacsql :source "elpaca-menu-lock-file" :recipe
	  (:package "emacsql" :fetcher github :repo "magit/emacsql"
		    :files (:defaults "README.md" "sqlite") :source
		    "elpaca-menu-lock-file" :protocol https :inherit t
		    :depth treeless :ref
		    "d6529f010a0573630122b826230e72157ab8fa88"))
 (embark :source "elpaca-menu-lock-file" :recipe
	 (:package "embark" :repo "oantolin/embark" :fetcher github
		   :files ("embark.el" "embark-org.el" "embark.texi")
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "d5df0eff182b014ab49328a4dbb1d69eb7faafbd"))
 (embark-consult :source "elpaca-menu-lock-file" :recipe
		 (:package "embark-consult" :repo "oantolin/embark"
			   :fetcher github :files
			   ("embark-consult.el") :source
			   "elpaca-menu-lock-file" :protocol https
			   :inherit t :depth treeless :ref
			   "d5df0eff182b014ab49328a4dbb1d69eb7faafbd"))
 (emmet-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "emmet-mode" :fetcher github :repo
		       "smihica/emmet-mode" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "322d3bb112fced57d63b44863357f7a0b7eee1e3"))
 (erlang-ts-mode :source "elpaca-menu-lock-file" :recipe
		 (:source "elpaca-menu-lock-file" :protocol https
			  :inherit t :depth treeless :host github
			  :repo "sebastiw/erlang-ts-mode" :package
			  "erlang-ts-mode" :ref
			  "ba5a01a2d7731a6fbf6129c6c8556fbceeb7d8a9"))
 (esup :source "elpaca-menu-lock-file" :recipe
       (:package "esup" :fetcher github :repo "jschaf/esup" :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "elpaca-menu-lock-file" :protocol https
		 :inherit t :depth treeless :ref
		 "4b49c8d599d4cc0fbf994e9e54a9c78e5ab62a5f"))
 (evil :source "elpaca-menu-lock-file" :recipe
       (:package "evil" :repo "emacs-evil/evil" :fetcher github :files
		 (:defaults "doc/build/texinfo/evil.texi"
			    (:exclude "evil-test-helpers.el"))
		 :source "elpaca-menu-lock-file" :protocol https
		 :inherit t :depth treeless :ref
		 "c222ce1ea6fbefaed08308c061371ebdf01b078f"))
 (evil-collection :source "elpaca-menu-lock-file" :recipe
		  (:package "evil-collection" :fetcher github :repo
			    "emacs-evil/evil-collection" :files
			    (:defaults "modes") :source
			    "elpaca-menu-lock-file" :protocol https
			    :inherit t :depth treeless :ref
			    "7ab9179591bc2f9474f480f52ec8dc44cf0a05f1"))
 (evil-commentary :source "elpaca-menu-lock-file" :recipe
		  (:package "evil-commentary" :repo
			    "linktohack/evil-commentary" :fetcher
			    github :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "elpaca-menu-lock-file" :protocol
			    https :inherit t :depth treeless :ref
			    "c5945f28ce47644c828aac1f5f6ec335478d17fb"))
 (evil-matchit :source "elpaca-menu-lock-file" :recipe
	       (:package "evil-matchit" :fetcher github :repo
			 "redguardtoo/evil-matchit" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "8a94e56bd2987c6d0c1a85fbf189f9a86e623cde"))
 (evil-surround :source "elpaca-menu-lock-file" :recipe
		(:package "evil-surround" :repo
			  "emacs-evil/evil-surround" :fetcher github
			  :old-names (surround) :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "da05c60b0621cf33161bb4335153f75ff5c29d91"))
 (exec-path-from-shell :source "elpaca-menu-lock-file" :recipe
		       (:package "exec-path-from-shell" :fetcher
				 github :repo
				 "purcell/exec-path-from-shell" :files
				 ("*.el" "*.el.in" "dir" "*.info"
				  "*.texi" "*.texinfo" "doc/dir"
				  "doc/*.info" "doc/*.texi"
				  "doc/*.texinfo" "lisp/*.el"
				  "docs/dir" "docs/*.info"
				  "docs/*.texi" "docs/*.texinfo"
				  (:exclude ".dir-locals.el" "test.el"
					    "tests.el" "*-test.el"
					    "*-tests.el" "LICENSE"
					    "README*" "*-pkg.el"))
				 :source "elpaca-menu-lock-file"
				 :protocol https :inherit t :depth
				 treeless :ref
				 "4896a797252fbfdac32fb77508500ac7d220f717"))
 (f :source "elpaca-menu-lock-file" :recipe
    (:package "f" :fetcher github :repo "rejeep/f.el" :files
	      ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
	       "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
	       "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
	       "docs/*.texinfo"
	       (:exclude ".dir-locals.el" "test.el" "tests.el"
			 "*-test.el" "*-tests.el" "LICENSE" "README*"
			 "*-pkg.el"))
	      :source "elpaca-menu-lock-file" :protocol https :inherit
	      t :depth treeless :ref
	      "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
 (feature-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "feature-mode" :repo
			 "michaelklishin/cucumber.el" :fetcher github
			 :files
			 ("*.el" "i18n.yml" "snippets" "support")
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "afd49b8a8504e5874027fc0a46283adb1fea26c0"))
 (flutter :source "elpaca-menu-lock-file" :recipe
	  (:package "flutter" :repo "amake/flutter.el" :fetcher github
		    :files
		    ("flutter.el" "flutter-project.el"
		     "flutter-l10n.el")
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "e71235d400787d977da7ed792709437899c2a03c"))
 (flymake-biome :source "elpaca-menu-lock-file" :recipe
		(:package "flymake-biome" :fetcher github :repo
			  "erickgnavar/flymake-biome" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "03fa55d23fdc80fb4bc963cd144da460e7da0220"))
 (flymake-markdownlint :source "elpaca-menu-lock-file" :recipe
		       (:package "flymake-markdownlint" :fetcher
				 codeberg :repo
				 "erickgnavar/flymake-markdownlint"
				 :files
				 ("*.el" "*.el.in" "dir" "*.info"
				  "*.texi" "*.texinfo" "doc/dir"
				  "doc/*.info" "doc/*.texi"
				  "doc/*.texinfo" "lisp/*.el"
				  "docs/dir" "docs/*.info"
				  "docs/*.texi" "docs/*.texinfo"
				  (:exclude ".dir-locals.el" "test.el"
					    "tests.el" "*-test.el"
					    "*-tests.el" "LICENSE"
					    "README*" "*-pkg.el"))
				 :source "elpaca-menu-lock-file"
				 :protocol https :inherit t :depth
				 treeless :host github :ref
				 "5167625b9ab958992ca68e225a0763c5c26b4eeb"))
 (flymake-ruff :source "elpaca-menu-lock-file" :recipe
	       (:package "flymake-ruff" :fetcher github :repo
			 "erickgnavar/flymake-ruff" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "970acdac865d5b6ee8541b82a413f3a107b9332e"))
 (flymake-sqlfluff :source "elpaca-menu-lock-file" :recipe
		   (:package "flymake-sqlfluff" :fetcher github :repo
			     "erickgnavar/flymake-sqlfluff" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "elpaca-menu-lock-file" :protocol
			     https :inherit t :depth treeless :ref
			     "0a836d7a919723ae5897fce01c3c7d651a30e8c6"))
 (flymake-yamllint :source "elpaca-menu-lock-file" :recipe
		   (:package "flymake-yamllint" :fetcher codeberg
			     :repo "shaohme/flymake-yamllint" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "elpaca-menu-lock-file" :protocol
			     https :inherit t :depth treeless :ref
			     "020d2a33568c8069801db9dd6992b8961a58de8d"))
 (font-utils :source "elpaca-menu-lock-file" :recipe
	     (:package "font-utils" :repo "rolandwalker/font-utils"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "abc572eb0dc30a26584c0058c3fe6c7273a10003"))
 (forge :source "elpaca-menu-lock-file" :recipe
	(:package "forge" :fetcher github :repo "magit/forge" :files
		  ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
		  "elpaca-menu-lock-file" :protocol https :inherit t
		  :depth treeless :ref
		  "33b074f6fbfea3e990a20c144dc33955bacba518"))
 (ghub :source "elpaca-menu-lock-file" :recipe
       (:package "ghub" :fetcher github :repo "magit/ghub" :files
		 ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
		 "elpaca-menu-lock-file" :protocol https :inherit t
		 :depth treeless :ref
		 "077e339bd714a0b8cafcb4ce2b9ec684b0509022"))
 (git-backup :source "elpaca-menu-lock-file" :recipe
	     (:package "git-backup" :fetcher github :repo
		       "antham/git-backup" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "67e38c659c918e98642171ba3f385a15182347f4"))
 (git-link :source "elpaca-menu-lock-file" :recipe
	   (:package "git-link" :fetcher github :repo "sshaw/git-link"
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "40f7b1674d2c703199ff2f82b464f17aa6f61b4b"))
 (git-modes :source "elpaca-menu-lock-file" :recipe
	    (:package "git-modes" :fetcher github :repo
		      "magit/git-modes" :old-names
		      (gitattributes-mode gitconfig-mode
					  gitignore-mode)
		      :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "f99010bbeb8b6d8a0819fac0195a2ef0159d08f0"))
 (git-timemachine :source "elpaca-menu-lock-file" :recipe
		  (:package "git-timemachine" :fetcher codeberg :repo
			    "pidu/git-timemachine" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "elpaca-menu-lock-file" :protocol
			    https :inherit t :depth treeless :ref
			    "d1346a76122595aeeb7ebb292765841c6cfd417b"))
 (go-mode :source "elpaca-menu-lock-file" :recipe
	  (:package "go-mode" :repo "dominikh/go-mode.el" :fetcher
		    github :files ("go-mode.el") :source
		    "elpaca-menu-lock-file" :protocol https :inherit t
		    :depth treeless :ref
		    "602d73e22646b1b98b2eb97927fd426c0d1d2f92"))
 (gotest :source "elpaca-menu-lock-file" :recipe
	 (:package "gotest" :fetcher github :repo
		   "nlamirault/gotest.el" :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "490189e68d743a851bfb42d0017428a7550e8615"))
 (goto-chg :source "elpaca-menu-lock-file" :recipe
	   (:package "goto-chg" :repo "emacs-evil/goto-chg" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "72f556524b88e9d30dc7fc5b0dc32078c166fda7"))
 (graphql-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "graphql-mode" :repo "davazp/graphql-mode"
			 :fetcher github :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "ee49531935ede7a2c9597713e13a4c9d33ef2220"))
 (haskell-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "haskell-mode" :repo "haskell/haskell-mode"
			 :fetcher github :files
			 (:defaults "NEWS" "logo.svg") :source
			 "elpaca-menu-lock-file" :protocol https
			 :inherit t :depth treeless :ref
			 "495fb9688e12ed1bf945b4876f124ee38b84c039"))
 (hcl-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "hcl-mode" :repo "hcl-emacs/hcl-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "1da895ed75d28d9f87cbf9b74f075d90ba31c0ed"))
 (helpful :source "elpaca-menu-lock-file" :recipe
	  (:package "helpful" :repo "Wilfred/helpful" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "34328c639ed7aad371a3f57209acad2a5bb66401"))
 (hide-mode-line :source "elpaca-menu-lock-file" :recipe
		 (:package "hide-mode-line" :repo
			   "hlissner/emacs-hide-mode-line" :fetcher
			   github :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "elpaca-menu-lock-file" :protocol
			   https :inherit t :depth treeless :ref
			   "ddd154f1e04d666cd004bf8212ead8684429350d"))
 (highlight-thing :source "elpaca-menu-lock-file" :recipe
		  (:package "highlight-thing" :fetcher github :repo
			    "fgeller/highlight-thing.el" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "elpaca-menu-lock-file" :protocol
			    https :inherit t :depth treeless :ref
			    "ad788d7a7ee9eb287a8cca3adb21510b89270dca"))
 (htmlize :source "elpaca-menu-lock-file" :recipe
	  (:package "htmlize" :fetcher github :repo
		    "hniksic/emacs-htmlize" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "8e3841c837b4b78bd72ad7f0436e919f39315a46"))
 (hydra :source "elpaca-menu-lock-file" :recipe
	(:package "hydra" :repo "abo-abo/hydra" :fetcher github :files
		  (:defaults (:exclude "lv.el")) :source
		  "elpaca-menu-lock-file" :protocol https :inherit t
		  :depth treeless :ref
		  "317e1de33086637579a7aeb60f77ed0405bf359b"))
 (hydra-posframe :source "elpaca-menu-lock-file" :recipe
		 (:source "elpaca-menu-lock-file" :protocol https
			  :inherit t :depth treeless :host github
			  :repo "Ladicle/hydra-posframe" :package
			  "hydra-posframe" :ref
			  "142a04dd588af6c725e331863c3ca7bd5dda13ec"))
 (imgur :source "elpaca-menu-lock-file" :recipe
	(:package "imgur" :fetcher github :repo "myuhe/imgur.el"
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :host github :main nil
		  :ref "ed952eb8f556c6fc0d982e2a689083504558cffb"))
 (inflections :source "elpaca-menu-lock-file" :recipe
	      (:package "inflections" :repo "eschulte/jump.el"
			:fetcher github :files ("inflections.el")
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"55caa66a7cc6e0b1a76143fd40eff38416928941"))
 (inheritenv :source "elpaca-menu-lock-file" :recipe
	     (:package "inheritenv" :fetcher github :repo
		       "purcell/inheritenv" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "b9e67cc20c069539698a9ac54d0e6cc11e616c6f"))
 (jit-spell :source "elpaca-menu-lock-file" :recipe
	    (:package "jit-spell" :repo
		      ("https://github.com/astoff/jit-spell"
		       . "jit-spell")
		      :files ("*" (:exclude ".git")) :source
		      "elpaca-menu-lock-file" :protocol https :inherit
		      t :depth treeless :ref
		      "54f6f69401cbaf3b103e5a2ff4bec34498098ef6"))
 (jsonian :source "elpaca-menu-lock-file" :recipe
	  (:package "jsonian" :fetcher github :repo "iwahbe/jsonian"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "f200035b847d6dd10bd7987f4540cff9edd3b881"))
 (know-your-http-well :source "elpaca-menu-lock-file" :recipe
		      (:package "know-your-http-well" :fetcher github
				:repo "for-GET/know-your-http-well"
				:files ("emacs/*.el") :source
				"elpaca-menu-lock-file" :protocol
				https :inherit t :depth treeless :ref
				"c916e825b0c75c2f2b6ff5ba79c981cff7de5797"))
 (latex-preview-pane :source "elpaca-menu-lock-file" :recipe
		     (:package "latex-preview-pane" :fetcher github
			       :repo "jsinglet/latex-preview-pane"
			       :files ("*.el" "*.txt") :source
			       "elpaca-menu-lock-file" :protocol https
			       :inherit t :depth treeless :ref
			       "5297668a89996b50b2b62f99cba01cc544dbed2e"))
 (lfe-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "lfe-mode" :fetcher github :repo "rvirding/lfe"
		     :files
		     ("emacs/inferior-lfe.el" "emacs/lfe-mode.el"
		      "emacs/lfe-indent.el")
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "2fb4de84f81ac822923ddc60eaccc4a938c9dfdc"))
 (ligature :source "elpaca-menu-lock-file" :recipe
	   (:package "ligature" :fetcher github :repo
		     "mickeynp/ligature.el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "6ac1634612dbd42f7eb81ecaf022bd239aabb954"))
 (linkode :source "elpaca-menu-lock-file" :recipe
	  (:package "linkode" :fetcher github :repo
		    "erickgnavar/linkode.el" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "5152aa3ba7a4360133efd5892f0891837af30440"))
 (list-utils :source "elpaca-menu-lock-file" :recipe
	     (:package "list-utils" :repo "rolandwalker/list-utils"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "bbea0e7cc7ab7d96e7f062014bde438aa8ffcd43"))
 (llama :source "elpaca-menu-lock-file" :recipe
	(:package "llama" :fetcher github :repo "tarsius/llama" :files
		  ("llama.el" ".dir-locals.el") :source
		  "elpaca-menu-lock-file" :protocol https :inherit t
		  :depth treeless :ref
		  "9802c215a3eea748d9d7f81a1465850388006897"))
 (llm :source "elpaca-menu-lock-file" :recipe
      (:package "llm" :repo ("https://github.com/ahyatt/llm" . "llm")
		:files ("*" (:exclude ".git")) :source
		"elpaca-menu-lock-file" :protocol https :inherit t
		:depth treeless :ref
		"874d76211c6933f2f5e41583a495e9b3aee51fb3"))
 (lv :source "elpaca-menu-lock-file" :recipe
     (:package "lv" :repo "abo-abo/hydra" :fetcher github :files
	       ("lv.el") :source "elpaca-menu-lock-file" :protocol
	       https :inherit t :depth treeless :ref
	       "317e1de33086637579a7aeb60f77ed0405bf359b"))
 (magit :source "elpaca-menu-lock-file" :recipe
	(:package "magit" :fetcher github :repo "magit/magit" :files
		  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
		   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
		   (:exclude "lisp/magit-section.el"))
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "3f2a501ec8c327da166e000c5bd9dd77e139aa65"))
 (magit-delta :source "elpaca-menu-lock-file" :recipe
	      (:package "magit-delta" :fetcher github :repo
			"dandavison/magit-delta" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"5fc7dbddcfacfe46d3fd876172ad02a9ab6ac616"))
 (magit-section :source "elpaca-menu-lock-file" :recipe
		(:package "magit-section" :fetcher github :repo
			  "magit/magit" :files
			  ("lisp/magit-section.el"
			   "docs/magit-section.texi"
			   "magit-section-pkg.el")
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "3f2a501ec8c327da166e000c5bd9dd77e139aa65"))
 (major-mode-hydra :source "elpaca-menu-lock-file" :recipe
		   (:package "major-mode-hydra" :repo
			     "jerrypnz/major-mode-hydra.el" :fetcher
			     github :files ("major-mode-hydra.el")
			     :source "elpaca-menu-lock-file" :protocol
			     https :inherit t :depth treeless :wait t
			     :ref
			     "d0a5dadee97c3752fcdef113cf2ba1923972a480"))
 (marginalia :source "elpaca-menu-lock-file" :recipe
	     (:package "marginalia" :repo "minad/marginalia" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "a527fb03b76a2bce1e360c6e73a095e06922c3f3"))
 (markdown-mode :source "elpaca-menu-lock-file" :recipe
		(:package "markdown-mode" :fetcher github :repo
			  "jrblevin/markdown-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "7659bc470d096e7a53285fa246cbabcb07d66a33"))
 (meme :source "elpaca-menu-lock-file" :recipe
       (:source "elpaca-menu-lock-file" :protocol https :inherit t
		:depth treeless :host github :repo "larsmagne/meme"
		:package "meme" :ref
		"3850a8dfafa15b3f2f988720fcc63c5a7e507ba6"))
 (merlin :source "elpaca-menu-lock-file" :recipe
	 (:package "merlin" :fetcher github :repo "ocaml/merlin"
		   :files
		   ("emacs/*.el"
		    (:exclude "emacs/merlin-ac.el"
			      "emacs/merlin-company.el"
			      "emacs/merlin-iedit.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "102eee422ce772174c71a22d97bdc7877918e509"))
 (merlin-eldoc :source "elpaca-menu-lock-file" :recipe
	       (:package "merlin-eldoc" :fetcher github :repo
			 "Khady/merlin-eldoc" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "bf8edc63d85b35e4def352fa7ce4ea39f43e1fd8"))
 (mermaid-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "mermaid-mode" :repo "abrochard/mermaid-mode"
			 :fetcher github :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "e74d4da7612c7a88e07f9dd3369e3b9fd36f396c"))
 (mise :source "elpaca-menu-lock-file" :recipe
       (:package "mise" :fetcher github :repo "eki3z/mise.el" :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "elpaca-menu-lock-file" :protocol https
		 :inherit t :depth treeless :ref
		 "97d244417d28605306f3a98eac0b67564677f277"))
 (multiple-cursors :source "elpaca-menu-lock-file" :recipe
		   (:package "multiple-cursors" :fetcher github :repo
			     "magnars/multiple-cursors.el" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "elpaca-menu-lock-file" :protocol
			     https :inherit t :depth treeless :ref
			     "dd10cf2334333838e4550f091a75695448e26765"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
	     (:package "nerd-icons" :repo
		       "rainstormstudio/nerd-icons.el" :fetcher github
		       :files (:defaults "data") :source
		       "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "f3e7ba37642455e5627968b1031faeefbcac1245"))
 (nerd-icons-completion :source "elpaca-menu-lock-file" :recipe
			(:package "nerd-icons-completion" :repo
				  "rainstormstudio/nerd-icons-completion"
				  :fetcher github :files
				  ("*.el" "*.el.in" "dir" "*.info"
				   "*.texi" "*.texinfo" "doc/dir"
				   "doc/*.info" "doc/*.texi"
				   "doc/*.texinfo" "lisp/*.el"
				   "docs/dir" "docs/*.info"
				   "docs/*.texi" "docs/*.texinfo"
				   (:exclude ".dir-locals.el"
					     "test.el" "tests.el"
					     "*-test.el" "*-tests.el"
					     "LICENSE" "README*"
					     "*-pkg.el"))
				  :source "elpaca-menu-lock-file"
				  :protocol https :inherit t :depth
				  treeless :ref
				  "8e5b995eb2439850ab21ba6062d9e6942c82ab9c"))
 (nerd-icons-dired :source "elpaca-menu-lock-file" :recipe
		   (:package "nerd-icons-dired" :repo
			     "rainstormstudio/nerd-icons-dired"
			     :fetcher github :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "elpaca-menu-lock-file" :protocol
			     https :inherit t :depth treeless :ref
			     "c0b0cda2b92f831d0f764a7e8c0c6728d6a27774"))
 (nix-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "nix-mode" :fetcher github :repo "NixOS/nix-mode"
		     :files
		     (:defaults
		      (:exclude "nix-company.el" "nix-mode-mmm.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "719feb7868fb567ecfe5578f6119892c771ac5e5"))
 (ob-d2 :source "elpaca-menu-lock-file" :recipe
	(:package "ob-d2" :repo "xcapaldi/ob-d2" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "5d197f8225a9fb4da997235b231abe30049c6825"))
 (odin-ts-mode :source "elpaca-menu-lock-file" :recipe
	       (:source "elpaca-menu-lock-file" :protocol https
			:inherit t :depth treeless :host github :repo
			"Sampie159/odin-ts-mode" :package
			"odin-ts-mode" :ref
			"495f425018531828a8304dc45288779e58d869ad"))
 (orderless :source "elpaca-menu-lock-file" :recipe
	    (:package "orderless" :repo "oantolin/orderless" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "c7cb04499d94ee1c17affb29b1cfcd2a45116c97"))
 (org-modern :source "elpaca-menu-lock-file" :recipe
	     (:package "org-modern" :repo "minad/org-modern" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "ae0d91fa16f0e72df50633d0941242eecd78721b"))
 (org-tree-slide :source "elpaca-menu-lock-file" :recipe
		 (:package "org-tree-slide" :fetcher github :repo
			   "takaxp/org-tree-slide" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "elpaca-menu-lock-file" :protocol
			   https :inherit t :depth treeless :ref
			   "e2599a106a26ce5511095e23df4ea04be6687a8a"))
 (package-lint :source "elpaca-menu-lock-file" :recipe
	       (:package "package-lint" :fetcher github :repo
			 "purcell/package-lint" :files
			 (:defaults "data" (:exclude "*flymake.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "6f05a369e0718e93c5dce0951cad5e6646296612"))
 (paredit :source "elpaca-menu-lock-file" :recipe
	  (:package "paredit" :fetcher git :url
		    "https://mumble.net/~campbell/git/paredit.git"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "elpaca-menu-lock-file" :protocol https
		    :inherit t :depth treeless :ref
		    "af075775af91f2dbc63b915d762b4aec092946c4"))
 (parrot :source "elpaca-menu-lock-file" :recipe
	 (:package "parrot" :fetcher github :repo "dp12/parrot" :files
		   (:defaults "img") :source "elpaca-menu-lock-file"
		   :protocol https :inherit t :depth treeless :ref
		   "1d381f24d74242018e306d1a0c891bed9a465ac3"))
 (parseclj :source "elpaca-menu-lock-file" :recipe
	   (:package "parseclj" :repo "clojure-emacs/parseclj"
		     :fetcher github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "6af22372e0fe14df882dd300b22b12ba2d7e00b0"))
 (parseedn :source "elpaca-menu-lock-file" :recipe
	   (:package "parseedn" :repo "clojure-emacs/parseedn"
		     :fetcher github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "3407e4530a367b6c2b857dae261cdbb67a440aaa"))
 (pbcopy :source "elpaca-menu-lock-file" :recipe
	 (:package "pbcopy" :fetcher github :repo
		   "emacsfodder/pbcopy.el" :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "338f7245746b5de1bb96c5cc2b32bfd9b5d83272"))
 (pcache :source "elpaca-menu-lock-file" :recipe
	 (:package "pcache" :repo "sigma/pcache" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "507230d094cc4a5025fe09b62569ad60c71c4226"))
 (persistent-soft :source "elpaca-menu-lock-file" :recipe
		  (:package "persistent-soft" :repo
			    "rolandwalker/persistent-soft" :fetcher
			    github :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "elpaca-menu-lock-file" :protocol
			    https :inherit t :depth treeless :ref
			    "a1e0ddf2a12a6f18cab565dee250f070384cbe02"))
 (perspective :source "elpaca-menu-lock-file" :recipe
	      (:package "perspective" :fetcher github :repo
			"nex3/perspective-el" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"e32d3ea731f6bc551ce196527b3cb0dc19d71151"))
 (plz :source "elpaca-menu-lock-file" :recipe
      (:package "plz" :repo
		("https://github.com/alphapapa/plz.el.git" . "plz")
		:files ("*" (:exclude ".git" "LICENSE")) :source
		"elpaca-menu-lock-file" :protocol https :inherit t
		:depth treeless :ref
		"9fb22d84d9e39692392276d7b7b9979ca6ca1c01"))
 (plz-event-source :source "elpaca-menu-lock-file" :recipe
		   (:package "plz-event-source" :repo
			     ("https://github.com/r0man/plz-event-source"
			      . "plz-event-source")
			     :files ("*" (:exclude ".git")) :source
			     "elpaca-menu-lock-file" :protocol https
			     :inherit t :depth treeless :ref
			     "e9c54b3325bcbcfd961d4d7d77316e59897f2232"))
 (plz-media-type :source "elpaca-menu-lock-file" :recipe
		 (:package "plz-media-type" :repo
			   ("https://github.com/r0man/plz-media-type"
			    . "plz-media-type")
			   :files ("*" (:exclude ".git")) :source
			   "elpaca-menu-lock-file" :protocol https
			   :inherit t :depth treeless :ref
			   "4404f213b4ba906668a4233e801610d984b26442"))
 (popper :source "elpaca-menu-lock-file" :recipe
	 (:package "popper" :fetcher github :repo "karthink/popper"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "faf155059e519fb036324af579c342365795dbbb"))
 (popup :source "elpaca-menu-lock-file" :recipe
	(:package "popup" :fetcher github :repo
		  "auto-complete/popup-el" :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "7a05700a37aae66d2b24f0cd8851f65383a5cf96"))
 (posframe :source "elpaca-menu-lock-file" :recipe
	   (:package "posframe" :fetcher github :repo
		     "tumashu/posframe" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "81651536827c96bf5af5265ee7918ab70e1dd5b1"))
 (pr-review :source "elpaca-menu-lock-file" :recipe
	    (:package "pr-review" :fetcher github :repo
		      "blahgeek/emacs-pr-review" :files
		      (:defaults "graphql") :source
		      "elpaca-menu-lock-file" :protocol https :inherit
		      t :depth treeless :ref
		      "9fa4ef4d1922cbd6dd37b631ea05aed0ef358178"))
 (pretty-hydra :source "elpaca-menu-lock-file" :recipe
	       (:package "pretty-hydra" :repo
			 "jerrypnz/major-mode-hydra.el" :fetcher
			 github :files ("pretty-hydra.el") :source
			 "elpaca-menu-lock-file" :protocol https
			 :inherit t :depth treeless :ref
			 "d0a5dadee97c3752fcdef113cf2ba1923972a480"))
 (pythontest :source "elpaca-menu-lock-file" :recipe
	     (:package "pythontest" :fetcher github :repo
		       "erickgnavar/pythontest.el" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "4bb4f330c13ef82bb6e4a4b15c47cb3fede83523"))
 (queue :source "elpaca-menu-lock-file" :recipe
	(:package "queue" :repo
		  ("https://git.savannah.gnu.org/git/emacs/elpa.git"
		   . "queue")
		  :branch "externals/queue" :files
		  ("*" (:exclude ".git")) :source
		  "elpaca-menu-lock-file" :protocol https :inherit t
		  :depth treeless :ref
		  "f986fb68e75bdae951efb9e11a3012ab6bd408ee"))
 (rainbow-delimiters :source "elpaca-menu-lock-file" :recipe
		     (:package "rainbow-delimiters" :fetcher github
			       :repo "Fanael/rainbow-delimiters"
			       :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "elpaca-menu-lock-file"
			       :protocol https :inherit t :depth
			       treeless :ref
			       "f40ece58df8b2f0fb6c8576b527755a552a5e763"))
 (rainbow-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "rainbow-mode" :repo
			 ("https://git.savannah.gnu.org/git/emacs/elpa.git"
			  . "rainbow-mode")
			 :branch "externals/rainbow-mode" :files
			 ("*" (:exclude ".git")) :source
			 "elpaca-menu-lock-file" :protocol https
			 :inherit t :depth treeless :ref
			 "f7db3b5919f70420a91eb199f8663468de3033f3"))
 (reformatter :source "elpaca-menu-lock-file" :recipe
	      (:package "reformatter" :repo
			"purcell/emacs-reformatter" :fetcher github
			:files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"f2cb59466b1c3f85a8c960f7d4b7b7ead015bedc"))
 (request :source "elpaca-menu-lock-file"
   :recipe
   (:package "request" :repo "tkf/emacs-request" :fetcher github
	     :files ("request.el") :source "elpaca-menu-lock-file"
	     :protocol https :inherit t :depth treeless :ref
	     "01e338c335c07e4407239619e57361944a82cb8a"))
 (restclient :source "elpaca-menu-lock-file" :recipe
	     (:package "restclient" :repo "pashky/restclient.el"
		       :fetcher github :files ("restclient.el")
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "e2a2b13482d72634f8e49864cd9e5c907a5fe137"))
 (s :source "elpaca-menu-lock-file" :recipe
    (:package "s" :fetcher github :repo "magnars/s.el" :files
	      ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
	       "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
	       "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
	       "docs/*.texinfo"
	       (:exclude ".dir-locals.el" "test.el" "tests.el"
			 "*-test.el" "*-tests.el" "LICENSE" "README*"
			 "*-pkg.el"))
	      :source "elpaca-menu-lock-file" :protocol https :inherit
	      t :depth treeless :ref
	      "dda84d38fffdaf0c9b12837b504b402af910d01d"))
 (sesman :source "elpaca-menu-lock-file" :recipe
	 (:package "sesman" :repo "vspinu/sesman" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "7bca68dbbab0af26a6a23be1ff5fa97f9a18e022"))
 (shrink-path :source "elpaca-menu-lock-file" :recipe
	      (:package "shrink-path" :fetcher gitlab :repo
			"bennya/shrink-path.el" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"c14882c8599aec79a6e8ef2d06454254bb3e1e41"))
 (slint-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "slint-mode" :fetcher github :repo
		       "nilclass/slint-mode" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "elpaca-menu-lock-file" :protocol https
		       :inherit t :depth treeless :ref
		       "168a6cfb90b5e36360074c83f80d5bbac2f0287e"))
 (sly :source "elpaca-menu-lock-file" :recipe
      (:package "sly" :repo "joaotavora/sly" :fetcher github :files
		(:defaults "lib" "slynk" "contrib" "doc/images"
			   (:exclude "sly-autoloads.el"))
		:version-regexp "%v" :source "elpaca-menu-lock-file"
		:protocol https :inherit t :depth treeless :ref
		"c48defcf58596e035d473f3a125fdd1485593146"))
 (spinner :source "elpaca-menu-lock-file" :recipe
	  (:package "spinner" :repo
		    ("https://github.com/Malabarba/spinner.el"
		     . "spinner")
		    :files ("*" (:exclude ".git")) :source
		    "elpaca-menu-lock-file" :protocol https :inherit t
		    :depth treeless :ref
		    "d4647ae87fb0cd24bc9081a3d287c860ff061c21"))
 (telega :source "elpaca-menu-lock-file" :recipe
	 (:package "telega" :fetcher github :repo "zevlg/telega.el"
		   :files
		   (:defaults "etc" "server" "contrib" "Makefile")
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "85ad1717de4a47ebeb293e836e5a89e901b55dbd"))
 (terraform-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "terraform-mode" :repo
			   "hcl-emacs/terraform-mode" :fetcher github
			   :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "elpaca-menu-lock-file" :protocol
			   https :inherit t :depth treeless :ref
			   "5bdd734a87f67f6574664f63eb4d02a0bc74c0d0"))
 (transient :source "elpaca-menu-lock-file" :recipe
	    (:package "transient" :fetcher github :repo
		      "magit/transient" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "32a7e256aab281bada5db8569e0871c8c3ad2115"))
 (treepy :source "elpaca-menu-lock-file" :recipe
	 (:package "treepy" :repo "volrath/treepy.el" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "651e2634f01f346da9ec8a64613c51f54b444bc3"))
 (treesit-auto :source "elpaca-menu-lock-file" :recipe
	       (:package "treesit-auto" :fetcher github :repo
			 "renzmann/treesit-auto" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "016bd286a1ba4628f833a626f8b9d497882ecdf3"))
 (treesit-ispell :source "elpaca-menu-lock-file" :recipe
		 (:package "treesit-ispell" :fetcher github :repo
			   "erickgnavar/treesit-ispell.el" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "elpaca-menu-lock-file" :protocol
			   https :inherit t :depth treeless :ref
			   "fd1598fb16fe99dc8d8245974641c3e474dc31d1"))
 (tuareg :source "elpaca-menu-lock-file" :recipe
	 (:package "tuareg" :fetcher github :repo "ocaml/tuareg"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "elpaca-menu-lock-file" :protocol https
		   :inherit t :depth treeless :ref
		   "1d53723e39f22ab4ab76d31f2b188a2879305092"))
 (typst-ts-mode :source "elpaca-menu-lock-file" :recipe
		(:package "typst-ts-mode" :repo
			  "meow_king/typst-ts-mode" :files
			  ("*" (:exclude ".git")) :source
			  "elpaca-menu-lock-file" :protocol https
			  :inherit t :depth treeless :type git :host
			  codeberg :ref
			  "972dc69d6b8a3f8983f6b8000654f59c8a8d05ba"))
 (ucs-utils :source "elpaca-menu-lock-file" :recipe
	    (:package "ucs-utils" :repo "rolandwalker/ucs-utils"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "91b9e0207fff5883383fd39c45ad5522e9b90e65"))
 (unicode-fonts :source "elpaca-menu-lock-file" :recipe
		(:package "unicode-fonts" :repo
			  "rolandwalker/unicode-fonts" :fetcher github
			  :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "6245b97d8ddaeaf1de4dbe2cd85ca0f3b20ef81b"))
 (vertico :source "elpaca-menu-lock-file" :recipe
	  (:package "vertico" :repo "minad/vertico" :files
		    (:defaults "extensions/vertico-*.el") :fetcher
		    github :source "elpaca-menu-lock-file" :protocol
		    https :inherit t :depth treeless :ref
		    "e69ef62ffa4bc42dd42437881c251ecdcae0e0c5"))
 (vertico-posframe :source "elpaca-menu-lock-file" :recipe
		   (:package "vertico-posframe" :repo
			     ("https://github.com/tumashu/vertico-posframe"
			      . "vertico-posframe")
			     :files ("*" (:exclude ".git")) :source
			     "elpaca-menu-lock-file" :protocol https
			     :inherit t :depth treeless :ref
			     "cfce055fadf1e96e729d90f86d921bdb6092eba5"))
 (visual-fill-column :source "elpaca-menu-lock-file" :recipe
		     (:package "visual-fill-column" :fetcher codeberg
			       :repo "joostkremers/visual-fill-column"
			       :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "elpaca-menu-lock-file"
			       :protocol https :inherit t :depth
			       treeless :ref
			       "11575df4e042f3263db62de0e8ee4f2331fbb1b4"))
 (vterm :source "elpaca-menu-lock-file" :recipe
	(:package "vterm" :fetcher github :repo
		  "akermu/emacs-libvterm" :files
		  ("CMakeLists.txt" "elisp.c" "elisp.h"
		   "emacs-module.h" "etc" "utf8.c" "utf8.h" "vterm.el"
		   "vterm-module.c" "vterm-module.h")
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "056ad74653704bc353d8ec8ab52ac75267b7d373"))
 (vterm-toggle :source "elpaca-menu-lock-file" :recipe
	       (:package "vterm-toggle" :fetcher github :repo
			 "jixiuf/vterm-toggle" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "elpaca-menu-lock-file" :protocol
			 https :inherit t :depth treeless :ref
			 "06cb4f3c565e46470a3c4505c11e26066d869715"))
 (wakatime-mode :source "elpaca-menu-lock-file" :recipe
		(:package "wakatime-mode" :fetcher github :repo
			  "wakatime/wakatime-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "elpaca-menu-lock-file" :protocol
			  https :inherit t :depth treeless :ref
			  "1c5b2254dd72f2ff504d6a6189a8c10be03a98d1"))
 (web-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "web-mode" :repo "fxbois/web-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "be2d59c8fa02b1a45ae54ce4079e502e659cefe6"))
 (websocket :source "elpaca-menu-lock-file" :recipe
	    (:package "websocket" :repo "ahyatt/emacs-websocket"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "elpaca-menu-lock-file" :protocol https
		      :inherit t :depth treeless :ref
		      "40c208eaab99999d7c1e4bea883648da24c03be3"))
 (wgrep :source "elpaca-menu-lock-file" :recipe
	(:package "wgrep" :fetcher github :repo
		  "mhayashi1120/Emacs-wgrep" :files ("wgrep.el")
		  :source "elpaca-menu-lock-file" :protocol https
		  :inherit t :depth treeless :ref
		  "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f"))
 (with-editor :source "elpaca-menu-lock-file" :recipe
	      (:package "with-editor" :fetcher github :repo
			"magit/with-editor" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"ca902ae02972bdd6919a902be2593d8cb6bd991b"))
 (writeroom-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "writeroom-mode" :fetcher github :repo
			   "joostkremers/writeroom-mode" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "elpaca-menu-lock-file" :protocol
			   https :inherit t :depth treeless :ref
			   "86965a56ed712ab70eb76577dc6fc5b01fd0eda6"))
 (xterm-color :source "elpaca-menu-lock-file" :recipe
	      (:package "xterm-color" :repo "atomontage/xterm-color"
			:fetcher github :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "elpaca-menu-lock-file" :protocol
			https :inherit t :depth treeless :ref
			"2ad407c651e90fff2ea85d17bf074cee2c022912"))
 (yaml :source "elpaca-menu-lock-file" :recipe
       (:package "yaml" :repo "zkry/yaml.el" :fetcher github :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "elpaca-menu-lock-file" :protocol https
		 :inherit t :depth treeless :ref
		 "73a9f5356284716a123952ce194c14ad9d183444"))
 (yaml-pro :source "elpaca-menu-lock-file" :recipe
	   (:package "yaml-pro" :repo "zkry/yaml-pro" :fetcher github
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "f7706ea170de98d29b7cdd5a4f189bd038b1e27b"))
 (yasnippet :source "elpaca-menu-lock-file" :recipe
	    (:package "yasnippet" :repo "joaotavora/yasnippet"
		      :fetcher github :files
		      ("yasnippet.el" "snippets") :source
		      "elpaca-menu-lock-file" :protocol https :inherit
		      t :depth treeless :ref
		      "5b315f1753480ebe669b157b8242448b5eafcfea"))
 (yasnippet-snippets :source "elpaca-menu-lock-file" :recipe
		     (:package "yasnippet-snippets" :repo
			       "AndreaCrotti/yasnippet-snippets"
			       :fetcher github :files
			       ("*.el" "snippets" ".nosearch") :source
			       "elpaca-menu-lock-file" :protocol https
			       :inherit t :depth treeless :ref
			       "f1907ed38acc479e78d5c113810465e4d77d8604"))
 (zig-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "zig-mode" :repo "ziglang/zig-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "elpaca-menu-lock-file" :protocol https
		     :inherit t :depth treeless :ref
		     "f0b4a487530146f99230f4a5ff67e8d56c8f3f80")))
