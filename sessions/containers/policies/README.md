# Kubernetes ValidatingAdmissionPolicy Examples (Digest, Registry, Signature, SBOM)

These are **native** `admissionregistration.k8s.io/v1` ValidatingAdmissionPolicy examples for:

- Digest enforce: only allow images referenced by immutable `@sha256:` digests.
- Registry enforce: restrict image sources to an allowed registry list.
- Signature + SBOM enforce: require attested metadata (annotations) that a signature and SBOM are present and verified.

> Important: ValidatingAdmissionPolicy cannot perform network calls or fetch image signatures/SBOMs. Signature/SBOM checks here enforce the presence of verification annotations you supply via CI or a separate controller (e.g., Sigstore policy-controller) — they do not verify artifacts themselves.

## Files

- `params.crd.yaml`: CRD defining `ImagePolicyParams` for configurable policy parameters.
- `params.default.yaml`: Cluster-scoped default parameters (allowed registries, digest/signature/SBOM requirements).
- `00-digest-enforce.yaml`: Policy + binding to enforce image digests on Pods.
- `01-registry-enforce.yaml`: Policy + binding to enforce allowed/blocked registries on Pods (uses params).
- `02-signature-sbom-enforce.yaml`: Policy + binding to enforce signature/SBOM annotations on Pods (uses params).

## Apply

```bash
kubectl apply -f policies/params.crd.yaml
kubectl apply -f policies/params.default.yaml
kubectl apply -f policies/00-digest-enforce.yaml
kubectl apply -f policies/01-registry-enforce.yaml
kubectl apply -f policies/02-signature-sbom-enforce.yaml
```

## Customize

Update `policies/params.default.yaml`:

- `allowedRegistries`: prefixes like `ghcr.io/`, `gcr.io/`, `registry.k8s.io/`.
- `requireDigest`: set `true` to force `@sha256:<64-hex>`.
- `requireSignature`: set `true` and define `signatureAnnotationKey` (default `cosign.sigstore.dev/verified`) and optional `signatureAnnotationValue` (`true`).
- `requireSBOM`: set `true` and define `sbomAnnotationKey` (URL or ref) and `sbom.dev/verified` style key to mark verification.

Optionally create per-namespace parameter objects and bind with a `ValidatingAdmissionPolicyBinding` setting `paramRef.namespace` or selectors.

## Notes & Limitations

- These policies match `Pods` on CREATE/UPDATE. For higher-level controllers (Deployments), admission evaluates the embedded PodTemplate; this is sufficient for most cases.
- Signature/SBOM checks rely on annotations on the incoming object. Integrate a CI step or controller to set:
  - `cosign.sigstore.dev/verified: "true"` after signature verification.
  - `sbom.dev/url: <URL>` and `sbom.dev/verified: "true"` after SBOM verification.
- For actual cryptographic enforcement, use Sigstore policy-controller or Kyverno in addition to these native policies.
