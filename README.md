## Fix My Kubernetes Cluster

This repo contains the scripts used in youtube series [Fix my kubernetes cluster](https://www.youtube.com/playlist?list=PL76FGzValKxGcJHvfGBy8toEP_QG5EHN7)

**Learning by doing is often the most effective way**, especially with complex systems like kubernetes. So, created a new series where we delve into Kubernetes internals by troubleshooting and fixing issues to grasp the intricacies of it. It's a hands-on, reverse engineering approach to grasp its complexities/concepts.

<br>
Each folder contains

- `create-cluster-with-issue.sh` script which creates kubernetes cluster using [kind](https://kind.sigs.k8s.io/) with an issue.
- few yaml files used to test the newly created kubernetes cluster

<br>
⭐ this repo if you find it useful

### Episode Details

- **First 4 episodes:** Two important components in Kubernetes architecture and internals of AuthN/AuthZ between these components.
- **Episodes 5,6,7:** Networking components in kubernetes

### How to use this repo
- Clone this repo
- cd into issue folder (eg: `cd 1/`)
- Run `./create-cluster-with-issue.sh`
    - It will create cluster with issue
    - And show some instructions on issue
- Now, you are ready to fix the broken cluster

### Contributions
- Feel free to create issues/pull-request for new type of issue which will be helpful for a new episode