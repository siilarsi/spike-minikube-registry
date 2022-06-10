# Running a custom Docker registry in minikube

To learn about:
- persistence of manifests, blobs, etc. in a storage backend
- potential concurrency issues when running multiple replicas
- caching of layer metadata for better performance
- custom retention of images
- the v2 API

## Usage

### Pre-requisites

Some tools are required on the local machine:

- kubectl
- minikube
- docker
- jq
- curl

Minikube should already be running and your kubectl context should be set to
using minikube.

*Important* to remember is to enable the ingress addon in minikube.

<details>
<summary>Optionally enable ingress-dns addon</summary>

Optionally the ingress-dns addon can be enabled as well, so that the hostname
specified in the ingress deployed to minikube can be resolved from your local
machine. But in order for that to work then you will have to [configure your
machine to use the ingress-dns addon as a dns
server](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/#solution).

Although for running the `run.sh` script that is not necessary as it relies
exclusively on curl with an option to resolve the hostname specified in the
ingress to the minikube IP.

Admittedly if you want to use `docker` to push images to the registry without
using the `./run.sh transfer` command, then using the ingress-dns addon is the
better solution.
</details>

### Instructions

Clone the repository and run the `run.sh` script:

```bash
$ ./run.sh
USAGE
  ./run.sh [ test | setup | teardown | deploy | transfer | catalog ]

COMMANDS
  test      run the test suite against the registry
            can be run independently

  setup     setup the test environment => minikube
  teardown  cleanup the test environment

  deploy    deploy the registry => minikube
  transfer  transfer an image to the deployed registry
  catalog   view the catalog of the deployed registry
```

### Test

Running the tests `./run.sh test` will create a sandbox environment for the
tests, by running a docker registry on the host machine on localhost:5000 and
creating a namespace "spike" in minikube.

The docker registry on the host machine is used to transfer images to the
docker registry running in minikube using the registry v2 API.

It will then deploy the docker registry to the spike namespace, exposing it
over an ingress with the host "registry.test".

Some tests are executed against the registry after which the sandbox
environment will be torn down again.

```bash
./run.sh test

[when] running the test suite
  [it] requires that the used tools are installed ✔
...
[when] deploying the registry
  [it] should be possible to reach the base URL ✔
```

### Debugging

Essentially most of what the tests do can also be done manually in order to
make debugging easier.

Here is an example flow:
```bash
$ ./run.sh setup
$ ./run.sh deploy
$ ./run.sh catalog
$ ./run.sh transfer
$ ./run.sh catalog
$ ./run.sh teardown
```
