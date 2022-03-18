when managing a large global environments with multiple sites patching can be tricky, the script will connect to multiple sites and devide the servers into phases automatically and updated the respective SCCM collections.

# XenAppPatchinglistgenerater
Generates phase wise patching list for XenApp member servers by connecting XenApp sites and updates SCCM Collection
script will generate phasewise servers by connecting to Xenapp sites.
  Phase1 - All servers in UAT.
  Phase2 - half of the servers in each DG from PROD site and any unconfigured servers.
  Phase3 - half the servers in each DG from PROD site.
  
Output will be saved in common location for reference

Script will update the respective SCCM collections using membership rule


# Pre-requisite
1) Citrix Module
2) ConfigurationManager Module(SCCM)
3) Permission to Xenapp sites and to update SCCM collections
4) script needs input in 2 files
    1) 1 for UAT sites DDC's
    2) 2 for PROD sites DDC's

