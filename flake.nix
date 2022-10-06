{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        mkScalacDerivation = { sourceDirectories, scalacOptions }@args:
          let
            params =
              builtins.concatMap
                pkgs.lib.filesystem.listFilesRecursive
                sourceDirectories
              ++ scalacOptions
              ++ [ "-d" "$out" ];

            finalArgs = {
              pname = "colorize-scala";
              version = "0.2.0";
              buildInputs = [ pkgs.scala ];

              buildCommand = ''
                mkdir $out
                scalac ${builtins.concatStringsSep " " params}
              '';
            } // (builtins.removeAttrs args [ "buildInputs" ]);
          in

          pkgs.stdenv.mkDerivation finalArgs;

        sbt-typelevel-defaults = {
          "2.13" = [
            "-deprecation"
            "-encoding"
            "UTF-8"
            "-feature"
            "-unchecked"
            "-Ywarn-numeric-widen"
            "-Xlint:deprecation"
            "-Wunused:nowarn"
            "-Wdead-code"
            "-Wextra-implicit"
            "-Wnumeric-widen"
            "-Wunused:implicits"
            "-Wunused:explicits"
            "-Wunused:imports"
            "-Wunused:locals"
            "-Wunused:params"
            "-Wunused:patvars"
            "-Wunused:privates"
            "-Wvalue-discard"
            "-Ywarn-dead-code"
            "-Ybackend-parallelism"
            "10"
            "-language:_"
          ];
        };
      in
      {
        packages.polyvariant.colorize-scala =
          let src = pkgs.fetchFromGitHub {
            owner = "polyvariant";
            repo = "colorize-scala";
            rev = "v0.2.0";
            sha256 = "sha256-eZaoqHLBcXGa4uvi/6yeJlcyVyhlaEE+YlSkcKkh4cQ=";
          }; in
          mkScalacDerivation {
            sourceDirectories = [ "${src}/core/shared/src/main/scala" ];
            scalacOptions = sbt-typelevel-defaults."2.13";
          };
      }
    );
}
