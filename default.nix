{ pkgs ? import <nixpkgs> { } }:
let
  k8s = pkgs.minikube;
in
pkgs.mkShell {
  name = "gencon pdf infra";
  packages = [k8s pkgs.kustomize];
  shellHook = ''
    set -a
    source .env

    SCRIPT_DIR=$PWD

    if ! pgrep "ingress" > /dev/null; then
      echo "Starting minikube"
      minikube start
      minikube addons enable ingress

    fi
  '';
  buildInputs = [];
}
