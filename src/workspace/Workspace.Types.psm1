class WorkspaceChild {}

class WorkspaceRepository : WorkspaceChild {
    [string]$type = 'repository'
    [string]$repository
    [string]$name
    [string]$path
    [string]$clone_url
}

class WorkspaceLogicalParent : WorkspaceChild {
    [string]$type = 'logical_parent'
    [string]$name
    [string]$path
    [WorkspaceRepository[]]$children
}

class Workspace {
    [string]$root
    [WorkspaceChild[]]$children
}