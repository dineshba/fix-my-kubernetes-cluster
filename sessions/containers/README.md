## Smaller, Faster, Safer: The Art of Building Better Container

### Why It Matters

- Containers are fast to deploy, but equally fast to spread risk if built poorly
- Most of the security issues are not start in Runtime, but in the build phase (vulnerable base images, secrets in layers, etc.)
- Misconfigured Dockerfiles led to real-world incidents:

  🧨 Tesla (2018) – exposed Kubernetes dashboard and images with secrets → crypto mining

  🐳 DockerHub leaks (2019) – leaked credentials in public images

- 90% of vulnerabilities in production images come from base images
- Less/No Code == secure


### Example of a Dockerfile

[Dockerfile](./Dockerfile)

### Optimizations of the Dockerfile

<details>
<summary>Base image pinning</summary>
Use a specific tag like golang:1.22 or golang:1.22-alpine instead of latest to reduce unexpected changes and CVEs.

```Dockerfile
FROM golang:1.22-alpine
...
```

</details>

<details>
<summary>Minimize packages</summary>
Remove tools like curl if not required. If needed, install only what's necessary and clean caches in the same layer.

```Dockerfile
# Debian/Ubuntu
RUN apt-get install -y --no-install-recommends curl && \
  rm -rf /var/lib/apt/lists/*
```

</details>

<details>
<summary>Layer reduction</summary>
Combine update and install into a single RUN to reduce layers and image size.

```Dockerfile
# Debian/Ubuntu example
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Alpine example (no separate update needed)
RUN apk add --no-cache curl
```

</details>

<details>
<summary>Inspect the layers</summary>

```sh
docker history <image>
dive <image>
```

</details>

<details>
<summary>Cache-friendly dependencies</summary>
Leverage Docker layer caching by downloading modules before copying source.

```Dockerfile
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
```

</details>

<details>
<summary>Smaller static binary</summary>
Build a smaller static binary by disabling CGO and stripping symbols.

```Dockerfile
ENV CGO_ENABLED=0
RUN go build -trimpath -ldflags "-s -w" -o /out/myapp .
```

</details>

<details>
<summary>Non-root user</summary>
Run as a non-root user in the final image for least privilege.

```Dockerfile
# Alpine
RUN adduser -D -u 10001 appuser
USER appuser

# Debian/Ubuntu
RUN useradd -u 10001 -m appuser
USER appuser
```

</details>

<details>
<summary>Multi-stage build</summary>
Compile in a builder stage, then copy only the binary into a minimal runtime.

```Dockerfile
# Builder
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ENV CGO_ENABLED=0
RUN go build -trimpath -ldflags "-s -w" -o /out/myapp .

# Final (scratch)
FROM scratch
COPY --from=builder /out/myapp /myapp
ENTRYPOINT ["/myapp"]
```

</details>

<details>
<summary>Minimal runtime base</summary>

Use `scratch` or a distroless base to reduce the attack surface.

```Dockerfile
# Distroless example (TLS-capable, non-root)
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /out/myapp /myapp
USER nonroot
ENTRYPOINT ["/myapp"]
```

</details>

<details>
<summary>.dockerignore hygiene</summary>
Exclude non-essential files from the build context to speed up builds and reduce image bloat.

```dockerignore
.git
**/.git
bin/
dist/
node_modules/
test/
*.md
Dockerfile*
.DS_Store
```

</details>

<details>
<summary>Entrypoint and defaults</summary>
Use ENTRYPOINT for the main executable and CMD for default arguments.

```Dockerfile
ENTRYPOINT ["/myapp"]
CMD ["--port=8080"]
```

</details>

<details>
<summary>Healthcheck</summary>
Add a healthcheck that works with your runtime base. For distroless/scratch, consider a self-check mode in the binary.

```Dockerfile
# Distroless/scratch example using app self-check
HEALTHCHECK --interval=30s --timeout=3s CMD ["/myapp", "--healthcheck"]

# Alpine example using sh + wget
HEALTHCHECK --interval=30s --timeout=3s CMD ["/bin/sh", "-c", "wget -qO- http://127.0.0.1:8080/health || exit 1"]
```
</details>


### Example of a Optmized Dockerfile
[Dockerfile](./Optimized.Dockerfile)

### Secure Containers


<details>
<summary>Check for digest instead of version/latest tag</summary>
Use immutable image digests (`image@sha256:...`) rather than mutable tags like `latest` or even version tags. Digests guarantee the exact artifact, preventing tag drift and supply-chain surprises.

```bash
# Pull and run by digest
docker pull ghcr.io/yourorg/myapp@sha256:aaaaaaaa...
docker run --rm ghcr.io/yourorg/myapp@sha256:aaaaaaaa...

# Find the digest for a tagged image (local or remote)
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/yourorg/myapp:1.2.3
# Optional (remote): requires crane from go-containerregistry
# crane digest ghcr.io/yourorg/myapp:1.2.3
```

```yaml
# Kubernetes: reference by digest for immutability
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: ghcr.io/yourorg/myapp@sha256:aaaaaaaa...
      imagePullPolicy: IfNotPresent
```

Admission policy examples to enforce digest usage:

```yaml
# Kyverno: require digests for containers and initContainers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digests
spec:
  validationFailureAction: enforce
  rules:
    - name: containers-must-use-digests
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: Images must use digests (image@sha256:...)
        anyPattern:
          - spec:
              containers:
                - image: "*@sha256:*"
          - spec:
              initContainers:
                - image: "*@sha256:*"
```

```yaml
# Gatekeeper/OPA: block images without @sha256
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequireimagedigest
spec:
  crd:
    spec:
      names:
        kind: K8sRequireImageDigest
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireimagedigest

        violation[{
          "msg": msg,
        }] {
          input.review.kind.kind == "Pod"
          img := input.review.object.spec.containers[_].image
          not contains(img, "@sha256:")
          msg := sprintf("container image %s must use digest (image@sha256:...)", [img])
        }
        violation[{
          "msg": msg,
        }] {
          input.review.kind.kind == "Pod"
          img := input.review.object.spec.initContainers[_].image
          not contains(img, "@sha256:")
          msg := sprintf("initContainer image %s must use digest (image@sha256:...)", [img])
        }
```

Notes: tags can be re-assigned, but digests are immutable; combine with signature verification (Cosign) for stronger guarantees.

</details>

<details>
<summary>Use env for passing secrets to containers</summary>
Prefer not to bake secrets into images. If your app accepts secrets via environment variables, pass them at runtime and avoid committing `.env` files.

```bash
# Docker: pass secrets via env-file (do not commit .env)
docker run --env-file .env --rm myapp:latest

# Docker Compose: reference environment and secrets
version: "3.8"
services:
  app:
    image: myapp:latest
    env_file:
      - .env
    # For sensitive data, prefer secrets over env when supported
    secrets:
      - db_password
secrets:
  db_password:
    file: ./secrets/db_password.txt
```

```yaml
# Kubernetes: use Secrets with env or mounted files
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DB_PASSWORD: c3VwZXJzZWNyZXQ=  # base64("supersecret")
---
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_PASSWORD
      volumeMounts:
        - name: secret-vol
          mountPath: /run/secrets
          readOnly: true
  volumes:
    - name: secret-vol
      secret:
        secretName: app-secrets
```

Tips: avoid printing envs in logs; rotate secrets; prefer mounted files where possible; ensure `.dockerignore` includes `.env`.

</details>

<details>
<summary>Use Trivy to scan image</summary>
Scan images and configs for known vulnerabilities and misconfigurations.

```bash
# Scan an image, focus on high/critical issues
trivy image --severity HIGH,CRITICAL --ignore-unfixed myapp:latest

# Scan local filesystem / Dockerfile for misconfigurations
trivy fs --severity HIGH,CRITICAL .
trivy config --severity HIGH,CRITICAL .

# Generate SBOM (CycloneDX) for downstream verification
trivy image --format cyclonedx --output sbom.json myapp:latest
```

</details>

<details>
<summary>Use Cosign to sign, attest and verify</summary>
Sign images and attach attestations (e.g., SBOM, build provenance).

```bash
# Generate a key pair (offline signing)
cosign generate-key-pair

# Sign the image
cosign sign --key cosign.key myapp:latest

# Verify the signature
cosign verify --key cosign.pub myapp:latest

# Create an SBOM and attach as an attestation
trivy image --format spdx --output sbom.spdx myapp:latest
cosign attest --key cosign.key \
  --type spdx \
  --predicate sbom.spdx \
  myapp:latest

# Verify the attestation (type-aware)
cosign verify-attestation --key cosign.pub \
  --type spdx \
  myapp:latest
```

Keyless signing via OIDC is also supported (`COSIGN_EXPERIMENTAL=1 cosign sign myapp:latest`).

</details>

<details>
<summary>SBOM + registry + signature policies (OPA/Gatekeeper, Kyverno, Sigstore)</summary>
Enforce allowed registries, required signatures, and SBOM/provenance at admission.

```yaml
# Gatekeeper: allow only images from approved registries
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          properties:
            repos:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedrepos
        violation[{
          "msg": msg,
          "details": {}}] {
          input.review.kind.kind == "Pod"
          repo := input.review.object.spec.containers[_].image
          not startswith(repo, allowed[_])
          msg := sprintf("image %v not from allowed registries", [repo])
        }
        allowed := {repo | repo := input.parameters.repos[_]}
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  parameters:
    repos:
      - "ghcr.io/yourorg/"
      - "registry.yourcorp.local/"
```

```yaml
# Sigstore Policy Controller: require signatures and SBOM attestation
apiVersion: policy.sigstore.dev/v1alpha1
kind: ClusterImagePolicy
metadata:
  name: require-signature-and-sbom
spec:
  images:
    - glob: "ghcr.io/yourorg/*"
  authorities:
    - key:
        secretRef:
          name: cosign-pub
  attestations:
    - name: sbom-required
      predicateType: https://spdx.dev/Document  # or cyclonedx
      authorities:
        - key:
            secretRef:
              name: cosign-pub
```

```yaml
# Kyverno: verify image signatures (alternative to Gatekeeper for signatures)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images
spec:
  rules:
    - name: require-sig
      match:
        resources:
          kinds:
            - Pod
      verifyImages:
        - imageReferences:
            - ghcr.io/yourorg/*
          attestors:
            - entries:
                - keys:
                    secret:
                      name: cosign-pub
                      key: cosign.pub
```

Notes: Gatekeeper/OPA can enforce registries and metadata; signature/SBOM verification is best handled by Sigstore Policy Controller or Kyverno.

</details>

