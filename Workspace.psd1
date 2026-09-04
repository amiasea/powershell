@{
    RootModule        = 'Workspace.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '00000000-0000-0000-0000-000000000000'
    Author            = 'Amiasea'
    Description       = 'Workspace resolution and build commands.'
    FunctionsToExport = @(
        'Resolve-Workspace'
        'Build-Workspace'
    )
}