class WorkspaceRepository {
    [string]$type = 'repository'
    [string]$repository
    [string]$name
    [string]$path
    [string]$clone_url
}

class WorkspaceLogicalParent {
    [string]$type = 'logical_parent'
    [string]$name
    [string]$path
    [WorkspaceRepository[]]$children
}

class Workspace {
    [string]$root
    [object[]]$children
}