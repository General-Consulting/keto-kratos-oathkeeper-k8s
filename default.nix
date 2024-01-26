{ pkgs ? import <nixpkgs> { } }:
let
  k8s = pkgs.minikube;
  postgres = pkgs.postgresql_16;
in
pkgs.mkShell {
  name = "gencon pdf infra";
  packages = [k8s pkgs.kustomize postgres];
  shellHook = ''
    set -a
    source .env


    echo
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
    echo 💡💡💡 General Consulting Dev Help 💡💡💡 
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
    echo
    # Check if minikube is already running
    if minikube status | grep -q "Running"; then
        echo "minikube is already running."
    else
        echo "Starting minikube..."
        minikube start
        minikube addons enable ingress
    fi
    echo run "minikube stop" to stop the cluster
    echo
    echo run "minikube dashboard" to bring up a general purpose web ui for monitoring your cluster.
    echo 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 💡💡💡 
  '';
  buildInputs = [];
}
