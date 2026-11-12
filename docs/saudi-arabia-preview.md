# Saudi Arabia early-access portal accelerator

This standalone copy is for testing by customers whose subscriptions have the
necessary region exceptions. It is not an official Microsoft release, a
production-readiness statement, or a commitment to a general-availability date.
The source and deployment templates retain the upstream [MIT license](../LICENSE).
This repository is public; do not commit customer information, credentials,
subscription IDs, tenant IDs, or parameter files containing them.

## Source and release provenance

- Source: [Azure/Enterprise-Scale](https://github.com/Azure/Enterprise-Scale).
- Exact upstream base: `fab1cb235e6ba1dad09396f700683723a6565a1a`
  (2026-10-20), verified against upstream `main` on 2026-11-11.
- At that base, upstream `src/portal/release.json` points to tag `2026-02-03`.
  Therefore this copy uses current source `main`, **not** the older release
  selected by that manifest. It is not claimed to match the live portal release.
- This copy's release manifest now points to its own matching template and UI.
  Microsoft's `aka.ms/alz/portal` entry point is not changed.

## What changed

The original first region picker is `Microsoft.Common.ResourceScope`, managed by
the portal. Its documented configuration does not expose an arbitrary region
list override. Adding a name to a networking dropdown cannot change that picker.

On **Deployment settings**, the replacement section first asks for an enabled
subscription in the current portal directory. Select one with your Saudi Arabia
exception. It then uses:

```text
GET /subscriptions/{selectedSubscription}/locations?api-version=2022-12-01
```

The required region picker displays the returned `displayName` and retains the
exact returned `name`. **No Saudi region API identifier is guessed or hardcoded.**
The authoritative identifier for your environment is the selected entry's `name`
from this subscription-specific API response. All returned regions remain
selectable; this change does not add a location that the API omits.

The discovery subscription is not passed as a platform subscription and does not
change the deployment scope. Choose the actual platform subscriptions on the
following tabs as before. Switch portal directory before starting if needed.
After changing discovery subscription, reselect and verify the region.

The replacement preserves `resourceScope.location.name` and `.displayName`.
Existing tenant `outputs.location`, first networking hub default, and monitoring
resource naming continue to use that shape. Other tabs, subscription-aware
networking controls, secondary-region options, and ARM templates are unchanged.

This is **not merely a metadata-only resource placement change**:
`eslzArm/eslzArm.json` uses `deployment().location` for linked deployments,
policy assignment identities, and some resource-location defaults. Subscription
access to a region does not establish that ARM accepts a tenant deployment there,
or that all required services, SKUs, policies and platform subscriptions are
eligible. Validate each separately. You may instead choose an existing supported
deployment-record region and select Saudi Arabia for supported resources on later
tabs, subject to your residency requirements and the template's actual defaults.

## Launch the custom portal form

[Open the Saudi Arabia early-access accelerator](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmoselim200%2Falz-saudi-arabia-preview%2Fmain%2FeslzArm%2FeslzArm.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fmoselim200%2Falz-saudi-arabia-preview%2Fmain%2FeslzArm%2Feslz-portal.json)

Opening this link loads the form; it is not evidence that a deployment succeeds.
Confirm the title ends with **Saudi Arabia early access**. This repository's
README deployment button opens the same custom form. Do not use Microsoft's
upstream deployment button or mix this UI with a different template version.

If you see the plain **Azure landing zone accelerator** title and the native
**Directory / Region** fields, without **Subscription with region access**, the
custom UI has not loaded. Close that deployment blade and open the custom link
above in a new tab. Use the commit-pinned link below if an older URL or cached
form persists. Do not continue testing region visibility in the original picker.

For repeatable customer testing, pin both URLs to the **same published commit**.
From a checkout of this repository, generate a pinned link without deploying:

```powershell
$revision = git rev-parse HEAD
$base = "https://raw.githubusercontent.com/moselim200/alz-saudi-arabia-preview/$revision/eslzArm"
$template = [uri]::EscapeDataString("$base/eslzArm.json")
$form = [uri]::EscapeDataString("$base/eslz-portal.json")
"https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/$template/uiFormDefinitionUri/$form"
```

Keep the **entire `eslzArm` directory hierarchy** at the same revision and URL
layout. Most linked deployment URIs resolve relative to
`deployment().properties.templateLink.uri`; uploading just the two top-level
JSON files or pasting the main template into the portal editor breaks that
resolution. Upstream optional external dependencies, including Azure Monitor
baseline alerts, remain unchanged and also require availability/access.

Public GitHub raw URLs are usable without sharing GitHub credentials. If this
repository becomes private later, those URLs will no longer work in the portal:
GitHub collaborator access is not sufficient for Azure's template fetches.
Use separately approved HTTPS hosting accessible to the portal and ARM, with the
same hierarchy. Do not put access tokens or SAS URLs in this repository.
No hosting or Azure resource provisioning is performed by these instructions.

## Verification before any deployment

Local regression checks (no Azure connection or resource creation):
Use Pester 5 or later.

```powershell
Import-Module Pester -MinimumVersion 5.0
$result = Invoke-Pester -Path .\tests\portal\SaudiArabiaPreview.Tests.ps1 -PassThru
if ($result.FailedCount -gt 0) { throw "Portal regression checks failed." }
```

These are structural regression checks, not a portal expression runtime or a live
Azure deployment. They check the subscription query binding, required picker and
output shape, unchanged later tabs/templates, linked files, matching launch URLs,
and inactive inherited automation.

At publication, all nine regression checks passed. The replacement section also
passed validation against the published Form view JSON schema. Schema validation
is limited to the changed section: unchanged upstream controls do not all satisfy
that schema (for example, the original hidden cloud warning uses `icon` instead
of `style`). Those pre-existing controls are intentionally not changed here.

Live acceptance still needs an authorized tester:

1. Open the custom link in the intended directory. Select the exception-enabled
   discovery subscription. Confirm the Saudi entry appears on the **first** tab.
2. Inspect the successful subscription locations response in browser developer
   tools and confirm the selected entry's exact `name` and `displayName`. A
   read-only alternative is
   `az account list-locations --subscription "<exception-enabled-subscription>" --query "[].{name:name,displayName:displayName}" -o table`.
   Do not save identifying account data in this public repository.
3. Switch to a subscription without access and confirm unavailable locations
   cannot remain selected. Return to the entitled subscription and reselect the
   region. If requests fail, lists are empty, or stale selection persists, stop;
   do not proceed on an unverified region.
4. Check single/dedicated subscriptions, no networking, hub-and-spoke, Virtual WAN,
   optional monitoring, and secondary-region paths relevant to your test. Confirm
   the review/output location matches the API `name`, and resource settings use
   the intended regions rather than unwanted defaults.
5. Before separately authorizing an actual deployment, establish tenant-scope
   deployment-location eligibility and service/SKU availability with your Azure
   early-access contact. Preview access alone does not establish either.

No live tenant validation or end-to-end deployment success is claimed.

## Automation safety

All seven inherited workflow files and Dependabot configuration are preserved in
`.github/disabled-workflows`, outside GitHub's active automation paths. In
particular, the upstream portal test workflow can deploy and destroy Azure
resources, and Scorecard can publish results. GitHub Actions is also disabled on
the destination repository. Do not restore or enable these without review.

## References

- [Form view and tenant output contract](https://learn.microsoft.com/azure/azure-resource-manager/templates/form-view-overview)
- [ResourceScope supported properties](https://learn.microsoft.com/azure/azure-resource-manager/templates/form-view-microsoft-common-resourcescope)
- [ArmApiControl dynamic requests](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/microsoft-solutions-armapicontrol)
- [Subscription locations API](https://learn.microsoft.com/rest/api/resources/subscriptions/list-locations?view=rest-resources-2022-12-01)
