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

    minikube start
    minikube addons enable ingress

    echo
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
    echo 💡💡💡 General Consulting Dev Help 💡💡💡 
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
    echo
    echo run "minikube stop" to stop the cluster
    echo
    echo run "minikube dashboard" to bring up a general purpose web ui for monitoring your cluster.
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
  '';
  buildInputs = [];
}
