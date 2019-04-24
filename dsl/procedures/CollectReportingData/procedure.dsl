// This procedure.dsl was generated automatically
// === procedure_autogen starts ===
procedure 'CollectReportingData', description: 'COLLECT REPORTING DATA', {

    step 'CollectReportingData', {
        description = ''
        command = new File(pluginDir, "dsl/procedures/CollectReportingData/steps/CollectReportingData.pl").text
        shell = 'ec-perl'
        
        
        
    }
// === procedure_autogen ends, checksum: 0772df1ac6a4ad80f15e262397675d45 ===
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}