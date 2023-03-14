{
  description = "Pretix ticketing software";

  inputs = {
    # Some utility functions to make the flake less boilerplaty
    flake-utils.url = "github:numtide/flake-utils";

    #nixpkgs.url = "github:nixos/nixpkgs/master";
    nixpkgs.url = "nixpkgs/nixos-22.11";

    pretixSrc = {
      url = "github:pretix/pretix/v4.17.1";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, pretixSrc, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          };
        in
        {
          defaultPackage = pkgs.pretix;
          packages = { inherit (pkgs) pretix update-pretix; };
        }) // {

      overlay = final: prev: {
        update-pretix = prev.writeScriptBin "update-pretix" ''
          #!/usr/bin/env bash

          set -euo pipefail
          set -x

          export PATH=${
            prev.lib.concatMapStringsSep ":" (x: "${x}/bin")
            (prev.stdenv.initialPath ++ [ final.poetry prev.stdenv.cc ])
          }:$PATH

          POETRY=${final.poetry}/bin/poetry

          workdir=$(mktemp -d)
          trap "rm -rf \"$workdir\"" EXIT

          pushd "$workdir"
          cp ${./pyproject.toml.template} pyproject.toml
          chmod +w pyproject.toml
          cat ${pretixSrc}/src/setup.py | \
            sed -n -e '/install_requires/,/]/p' | head -n -1 | tail -n +2 | sed -e "s/',//g" -e "s/\s*'//g" -e 's/#.*//' -e 's/\([=<>]\)/@&/' | \
            xargs "$POETRY" add

          poetry add gunicorn cryptography\<29.0.2

          cp ${pretixSrc}/src/pretix/static/npm_dir/{package.json,package-lock.json} ./

          ${final.nodePackages.node2nix}/bin/node2nix --development -l ./package-lock.json -i ./package.json

          popd
          cp "$workdir"/{pyproject.toml,poetry.lock,node-packages.nix,node-env.nix,package.json,package-lock.json} ./
          cp "$workdir"/default.nix ./node.nix
        '';

        pretix-app = let
          nodejs = final.nodejs-14_x;

          nodeDependencies = ((final.callPackage ./node.nix {
	    inherit nodejs;
	  }).shell.override (old: {
	    src = pretixSrc + "/src/pretix/static/npm_dir/";
	  })).nodeDependencies;
        in prev.poetry2nix.mkPoetryApplication {
          projectDir = pretixSrc;
          pyproject = ./pyproject.toml;
          poetrylock = ./poetry.lock;
          src = pretixSrc + "/src";
          overrides = prev.poetry2nix.overrides.withDefaults (pself: psuper: {
            # The tlds package is an ugly beast which fetches its content
            # at build-time. So instead replace it by a fixed hardcoded
            # version.
            tlds = psuper.tlds.overrideAttrs (a: {
              src = prev.fetchFromGitHub {
                owner = "n0emis";
                repo = "tlds";
                rev = "0bea3cd1e6dd90c472933194a1137a1ea065a812";
                sha256 =
                  "sha256-lW9hHfZLkXCpLOvYQ/5tVrurYY2OAP1wPu6cIz6n0+I=";
              };
              buildInputs = (a.buildInputs or [ ])
                ++ [ psuper.setuptools ];
            });
            django-scopes = psuper.django-scopes.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
              # Django-scopes does something fishy to determine its version,
              # which breaks with Nix
              prePatch = (a.prePatch or "") + ''
                sed -i "s/version = '?'/version = '${a.version}'/" setup.py
              '';
            });
	    css-inline = psuper.css-inline.override {
              preferWheel = true;
            };
            django-hijack = psuper.django-hijack.overridePythonAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
                ++ [ psuper.setuptools-scm ];
              prePatch = (a.prePatch or "") + ''
                sed -i 's|cmd = \["npm", "run", "build"\]|cmd = ["${prev.nodejs}/bin/node", "${prev.nodePackages.postcss}/lib/node_modules/postcss/package.json", "hijack/static/hijack/hijack.scss", "-o", "/hijack/static/hijack/hijack.min.css"]|' setup.py
                sed -ie '/cmd = \["npm", "ci"\]/,+2d' setup.py
              '';
            });
            defusedcsv = psuper.defusedcsv.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            pypdf2 = psuper.pypdf2.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.poetry psuper.flit-core ];
            });
            click-didyoumean = psuper.click-didyoumean.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.poetry ];
            });
            django-i18nfield = psuper.django-i18nfield.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            slimit = psuper.slimit.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.flit-scm ];
            });
            phonenumberslite = psuper.phonenumberslite.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-hierarkey = psuper.django-hierarkey.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            pyuca = psuper.pyuca.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            pypdf = psuper.pypdf.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.flit-core ];
            });
            static3 = psuper.static3.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            vat-moss-forked = psuper.vat-moss-forked.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            dj-static = psuper.dj-static.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-bootstrap3 = psuper.django-bootstrap3.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-jquery-js = psuper.django-jquery-js.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-localflavor = psuper.django-localflavor.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-markup = psuper.django-markup.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-mysql = psuper.django-mysql.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-phonenumber-field = psuper.django-phonenumber-field.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools-scm ];
            });
            django-formset-js-improved = psuper.django-formset-js-improved.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            drf-ujson2 = psuper.drf-ujson2.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            python-u2flib-server = psuper.python-u2flib-server.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            paypalhttp = psuper.paypalhttp.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            paypal-checkout-serversdk = psuper.paypal-checkout-serversdk.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });
            django-libsass = psuper.django-libsass.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ psuper.setuptools ];
            });

            reportlab = let 
              ft = prev.freetype.overrideAttrs (oldArgs: { dontDisableStatic = true; });
            in psuper.reportlab.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ ft ];

              postPatch = ''
                substituteInPlace setup.py \
                  --replace "mif = findFile(d,'ft2build.h')" "mif = findFile('${final.lib.getDev ft}','ft2build.h')"
              '';
            });

            pretix = psuper.pretix.overrideAttrs (a: {
              buildInputs = (a.buildInputs or [ ])
              ++ [ prev.nodePackages.npm ];
            });
          });
          prePatch = ''
            sed -i "/subprocess.check_call('npm install'/d" setup.py
          '';
          preBuild = ''
            mkdir -p pretix/static.dist/node_prefix/
            ln -s ${nodeDependencies}/lib/node_modules ./pretix/static.dist/node_prefix/node_modules
            export PATH="${nodeDependencies}/bin:$PATH"
          '';
          doInstallCheck = false;
          nativeBuildInputs = [
            prev.nodePackages.npm
            nodeDependencies
          ];
        };
        pretix = final.pretix-app.dependencyEnv;
      };

      nixosModules.pretix = {
        imports = [ ./nixos-module.nix ];
        nixpkgs.overlays = [ self.overlay ];
      };

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.pretix
          ({ config, lib, pkgs, ... }:
            let
              # XXX: Should be passed out-of-band so as to not end-up in the
              # Nix store
              pretix_secret_cfg = pkgs.writeText "pretix-secrets"
                (lib.generators.toKeyValue { } {
                  PRETIX_DATABASE_PASSWORD = "foobar";
                });
            in
            {
              system.configurationRevision = self.rev or "dirty";

              services.pretix = {
                enable = true;
                config = {
                  database = {
                    backend = "postgresql";
                    name = "pretix";
                    host = "localhost";
                    user = "pretix";
                  };
                };
                secretConfig = pretix_secret_cfg;
                host = "0.0.0.0";
                port = 8000;
              };

              # Ad-hoc initialisation of the database password.
              # Ideally the postgres host is on another machine and handled
              # separately
              systemd.services.pretix-setup = {
                script = ''
                  # Setup the db
                  set -eu

                  ${pkgs.utillinux}/bin/runuser -u ${config.services.postgresql.superUser} -- \
                    ${config.services.postgresql.package}/bin/psql -c \
                    "ALTER ROLE ${config.services.pretix.config.database.user} WITH PASSWORD '$PRETIX_DATABASE_PASSWORD'"
                '';

                after = [ "postgresql.service" ];
                requires = [ "postgresql.service" ];
                before = [ "pretix.service" ];
                requiredBy = [ "pretix.service" ];
                serviceConfig.EnvironmentFile = pretix_secret_cfg;
              };

              networking.firewall.allowedTCPPorts =
                [ config.services.pretix.port ];

              networking.hostName = "pretix";
              services.getty.autologinUser = "root";
            })
        ];
      };
    };
}
