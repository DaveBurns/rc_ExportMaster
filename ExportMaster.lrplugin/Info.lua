--[[
        Info.lua
--]]

return {
    appName = "Export Master",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.ExportMaster",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "RC Export Master",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 3.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/MiscLrPlugins/#www.robcole.com",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.lightroom.ExportMaster",
    LrInitPlugin = "Init.lua",
    -- shutdown is not compatible with this plugin - it causes premature termination if attended to in async export filter processing.
    LrExportFilterProvider = {
        title = "Export Master",
        file = "ExtendedExportFilter.lua",
        id = "com.robcole.exportfilter.ExportMaster",
    },
    LrTagsetProvider = "Tagsets.lua", -- init upon startup.
    VERSION = { display = "1.1.1    Build: 2011-11-16 06:30:05" },
}
