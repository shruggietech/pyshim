namespace Pyshim.Setup;

/// <summary>
///  Plain-old-data record describing which installation actions the user picked.
/// </summary>
internal sealed record InstallerOptions(
    bool EnsurePath,
    bool AddCurrentUserProfiles,
    bool AddAllUserProfiles,
    bool RefreshConda)
{
    internal bool RequirePwshProfileWork => AddCurrentUserProfiles || AddAllUserProfiles;
}
