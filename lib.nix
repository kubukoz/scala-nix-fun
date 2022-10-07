final: prev:
let
  pkgs = prev;

  mkScalacDerivation =
    { pname
    , version
    , src
    , sourceDirectories ? [ ]
    , scalacOptions ? [ ]
    , buildInputs ? [ ]
    , resourceDirectories ? [ ]
    }@args:
    let
      isDir = path:
        let
          base = baseNameOf path;
          type = (builtins.readDir (dirOf path)).${base} or null;
        in
        type == "directory";

      listFilesOrGet = path:
        if isDir path then
          pkgs.lib.filesystem.listFilesRecursive path
        else [ path ];

      params = scalacOptions ++ [ "-d" "out" ];

      finalArgs = {
        name = "${pname}-${version}";
        buildInputs = [ pkgs.scala pkgs.strip-nondeterminism ];
        # todo rename arg
        propagatedBuildInputs = buildInputs;

        inherit sourceDirectories resourceDirectories params;

        buildPhase = ''
          source_paths=$(find $sourceDirectories -type f)
          mkdir out
          scalac $source_paths $params
        '';

        installPhase = ''
          for resourceDir in $resourceDirectories; do
            cp -r $resourceDir/* out
          done

          cd out
          jar cf result.jar *
          strip-nondeterminism result.jar
          mkdir -p $out/share/java
          cp result.jar $out/share/java/${pname}.jar
        '';
      } // (builtins.removeAttrs args [ "buildInputs" ]);
    in

    pkgs.stdenv.mkDerivation finalArgs;

  mkScalaApp = { package ? [ ], mainClass }: pkgs.stdenv.mkDerivation
    {
      name = package.pname + "-app";
      buildInputs = [ pkgs.scala pkgs.makeWrapper package ];
      buildPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.scala}/bin/scala $out/bin/$name --add-flags "-cp $CLASSPATH ${mainClass}"
      '';
      dontUnpack = true;
      installPhase = "true";
    };

  fetchMavenArtifact =
    { version
    , pname
    , artifact
    , org
    , sha256
    , propagatedBuildInputs ? [ ]
    }:
    let url = "https://repo1.maven.org/maven2/${builtins.concatStringsSep "/" org}/${artifact}/${version}/${artifact}-${version}.jar"; in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      src = builtins.fetchurl {
        inherit url sha256;
      };
      buildInputs = [ pkgs.jre ];
      inherit propagatedBuildInputs;
      buildPhase = ''
        mkdir -p $out/share/java
        cp $src $out/share/java/$pname.jar
      '';
      dontUnpack = true;
      installPhase = "true";
    };
in
{ scala-tools = { inherit mkScalacDerivation mkScalaApp fetchMavenArtifact; }; }
