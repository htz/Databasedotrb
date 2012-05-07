Databasedotrb
=============

`sfdc:001> ?`
`Command line help:`
``
`     ?          # All command line help.`
`     exit       # Exit command line.`
`     set        # Set configuration.`
`                    set [config name] (value)`
`     no         # Unset configuration.`
`                    no [config name]`
`     config     # Show all configurations.`
`     sobjects   # Show all sObjects.`
`                    sobjects       # basic sobject list`
`                    sobjects dev   # developer sobject list`
`                    sobjects all   # all sobject describe`
`     query      # SOQL query.`
`                    query [SOQL query]`
`                    ex.: query "Select * From User Limit 10"`
`     search     # SOSL search.`
`                    search [SOSL query]              # execute sosl query`
`                    search [search string] all       # search all field`
`                    search [search string] name      # search name field`
`                    search [search string] email     # search email field`
`                    search [search string] phone     # search phone field`
`                    search [search string] sidebar   # search sidebar field`
`     export     # Export for CSV file (before command result data).`
`                    export               # export csv for stdout`
`                    export [file name]   # export csv for file`
`     insert     # Insert from local CSV file.`
`                    insert [sObject] [file name]`
`     update     # Update from CSV local file.`
`                    update [sObject] [file name]`
`     upsert     # Upsert from CSV local file.`
`                    upsert [sObject] [ID or External ID field] [file name]`
`     delete     # Delete from CSV local file.`
`                    delete [sObject] [file name]`
`     next       # Next page.`
``
`sObject Command line help:`
``
`    [sObject]          # Describe sObject.`
`    [sObject] find     # Find sObject record for ID or External ID.`
`                           [sObject] find [ID]                                     # find ID record`
`                           [sObject] find [External ID field name]/[External ID]   # find External ID record`
`    [sObject] all      # Show all sObject records.`
`                           [sObject] all ([field list])`
`                           ex.: User all "Id,FirstName"`
`    [sObject] full     # Show all sObject records.`
`    [sObject] count    # Count all sObject records.`
`                           [sObject] count`
`    [sObject] first    # Show first sObject record.`
`                           [sObject] first ([field list])`
`                           ex.: User first "Id,FirstName"`
`    [sObject] last     # Show last sObject record.`
`                           [sObject] last ([field list])`
`                           ex.: User last "Id,FirstName"`
`    [sObject] query    # SOQL query by sObject.`
`                           [sObject] query [where expr] ([field list])   # [where expr] is WHERE part of a SOQL query`
`                           ex.: User query "FirstName like 'R%'"`
`    [sObject] delete   # Delete sObject record for ID or External ID.`
`                           [sObject] delete [ID]                                     # delete ID record`
`                           [sObject] delete [External ID field name]/[External ID]   # delete External ID record`
``
`History Command line help:`
`  [history] is commandline history result data.`
`  [$ or $n](:[n or n-m](,[n or n-m](,[n or n-m],(...))))`
`  ex.: $         # before result data`
`  ex.: $7        # line number 7 result data`
`  ex.: $7:1,3    # line number 7 result data (1 and 3 row data)`
`  ex.: $:1-3,5   # before result data (1, 2, 3 and 5 row data)`
``
`    [history]          # Show data.`
`    [history] export   # Export for CSV file (before command result data).`
`                           [history] export               # export csv for stdout`
`                           [history] export [file name]   # export csv for file`
`                           ex.: $7:1,3 export example.csv`
`    [history] delete   # Delete sObject records.`
`                           [history] delete`
`                           ex.: $7:1,3 delete`

