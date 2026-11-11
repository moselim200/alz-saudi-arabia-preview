BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $baseRevision = 'fab1cb235e6ba1dad09396f700683723a6565a1a'
    $portalText = Get-Content (Join-Path $root 'eslzArm\eslz-portal.json') -Raw
    $portal = $portalText | ConvertFrom-Json
    $baselineText = & git -C $root show "${baseRevision}:eslzArm/eslz-portal.json"
    if ($LASTEXITCODE -ne 0) { throw 'The upstream base revision is required for regression checks.' }
    $baseline = ($baselineText -join "`n") | ConvertFrom-Json
    $basics = $portal.view.properties.steps | Where-Object name -EQ 'basics'
    $scope = $basics.elements | Where-Object name -EQ 'resourceScope'
    $subscription = $scope.elements | Where-Object name -EQ 'discoverySubscription'
    $locationsApi = $scope.elements | Where-Object name -EQ 'getDeploymentLocations'
    $location = $scope.elements | Where-Object name -EQ 'location'
    $release = Get-Content (Join-Path $root 'src\portal\release.json') -Raw | ConvertFrom-Json
}

Describe 'Saudi Arabia subscription-discovered first region' {
    It 'replaces the native picker with required subscription discovery on the first tab' {
        $portal.view.properties.steps[0].name | Should -Be 'basics'
        $scope.type | Should -Be 'Microsoft.Common.Section'
        $subscription.type | Should -Be 'Microsoft.Common.DropDown'
        $subscription.constraints.required | Should -BeTrue
        $subscription.constraints.allowedValues | Should -Be "[steps('basics').getSubscriptions.data]"
        $subscription.defaultValue | Should -Be "[parse('[]')]"
        $portalText | Should -Not -Match '"type":\s*"Microsoft.Common.ResourceScope"'
    }

    It 'queries the selected subscription instead of the tenant or implicit portal subscription' {
        $locationsApi.type | Should -Be 'Microsoft.Solutions.ArmApiControl'
        $locationsApi.condition | Should -Be "[not(empty(steps('basics').resourceScope.discoverySubscription))]"
        $locationsApi.request.method | Should -Be 'GET'
        $locationsApi.request.path | Should -Be "[concat('/subscriptions/', steps('basics').resourceScope.discoverySubscription, '/locations?api-version=2022-12-01')]"
    }

    It 'preserves API names and display names without a hardcoded region or fallback' {
        $location.type | Should -Be 'Microsoft.Common.DropDown'
        $location.constraints.required | Should -BeTrue
        $location.defaultValue | Should -Be "[parse('[]')]"
        $location.constraints.allowedValues | Should -Be '[map(steps(''basics'').resourceScope.getDeploymentLocations.value, (item) => parse(concat(''{"label":"'', item.displayName, ''","value":{"name":"'', item.name, ''","displayName":"'', item.displayName, ''"}}'')))]'
        $scope.elements.name | Should -Contain 'earlyAccessWarning'
    }

    It 'preserves every existing output binding including the tenant location' {
        $portal.view.outputs.kind | Should -Be 'Tenant'
        $portal.view.outputs.location | Should -Be "[steps('basics').resourceScope.location.name]"
        ($portal.view.outputs | ConvertTo-Json -Depth 100 -Compress) |
            Should -Be ($baseline.view.outputs | ConvertTo-Json -Depth 100 -Compress)
    }

    It 'leaves other first-tab discovery controls and all later scenarios unchanged' {
        $originalBasics = $baseline.view.properties.steps | Where-Object name -EQ 'basics'
        ($basics.elements | Where-Object name -NE 'resourceScope' | ConvertTo-Json -Depth 100 -Compress) |
            Should -Be ($originalBasics.elements | Where-Object name -NE 'resourceScope' | ConvertTo-Json -Depth 100 -Compress)
        ($portal.view.properties.steps | Where-Object name -NE 'basics' | ConvertTo-Json -Depth 100 -Compress) |
            Should -Be ($baseline.view.properties.steps | Where-Object name -NE 'basics' | ConvertTo-Json -Depth 100 -Compress)
    }

    It 'does not modify ARM templates or the other cloud UI' {
        $changed = & git -C $root diff --name-only $baseRevision -- eslzArm
        if ($LASTEXITCODE -ne 0) { throw 'Unable to compare ARM files to the upstream base.' }
        @($changed).Count | Should -Be 1
        $changed | Should -Be 'eslzArm/eslz-portal.json'
    }
}

Describe 'Custom portal publication safety' {
    It 'pairs the custom UI and template on the same repository and revision' {
        $prefix = 'https://raw.githubusercontent.com/moselim200/alz-saudi-arabia-preview/main/eslzArm/'
        $release.templateUri | Should -Be ($prefix + 'eslzArm.json')
        $release.uiFormDefinitionUri | Should -Be ($prefix + 'eslz-portal.json')
        $doc = Get-Content (Join-Path $root 'docs\saudi-arabia-preview.md') -Raw
        $template = [uri]::EscapeDataString($release.templateUri)
        $form = [uri]::EscapeDataString($release.uiFormDefinitionUri)
        $doc | Should -Match ([regex]::Escape("CustomDeploymentBlade/uri/$template/uiFormDefinitionUri/$form"))
    }

    It 'retains all literal relative linked templates at their original paths' {
        $templatePath = Join-Path $root 'eslzArm\eslzArm.json'
        $template = Get-Content $templatePath -Raw | ConvertFrom-Json
        $relativeLinks = @($template.variables.deploymentUris.PSObject.Properties.Value |
            Where-Object { $_ -match "^\[uri\(deployment\(\)\.properties\.templateLink\.uri, '" })
        $relativeLinks.Count | Should -BeGreaterThan 0
        foreach ($link in $relativeLinks) {
            $link | Should -Match "^\[uri\(deployment\(\)\.properties\.templateLink\.uri, '([^']+)'\)\]$"
            $relativePath = [regex]::Match($link, ", '([^']+)'").Groups[1].Value
            Test-Path (Join-Path (Split-Path $templatePath) $relativePath) | Should -BeTrue
        }
    }

    It 'keeps inherited workflows and Dependabot outside active automation paths' {
        $active = @(Get-ChildItem (Join-Path $root '.github\workflows') -File -ErrorAction SilentlyContinue |
            Where-Object Extension -In '.yml', '.yaml')
        $active.Count | Should -Be 0
        Test-Path (Join-Path $root '.github\dependabot.yml') | Should -BeFalse
        $archived = @(Get-ChildItem (Join-Path $root '.github\disabled-workflows') -File)
        $archived.Count | Should -Be 8
        foreach ($file in $archived) {
            $originalPath = if ($file.Name -eq 'dependabot.yml') {
                '.github/dependabot.yml'
            } else {
                ".github/workflows/$($file.Name)"
            }
            $original = & git -C $root show "${baseRevision}:$originalPath"
            if ($LASTEXITCODE -ne 0) { throw "Unable to read archived automation base: $originalPath" }
            ((Get-Content $file.FullName) -join "`n") | Should -Be ($original -join "`n")
        }
    }
}
