***************************************
* 1. Read raw data, retain selected variables, create the 'month' `zipcode(first 5 numbers)' variable, and drop 2014 data
***************************************
import delimited "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/log/ratewatch_AllBanks_uniformpricing_newest_multi_branches.csv", clear

* Keep only the required variables (including county and primarycompany)
keep accountnumber productdescription datesurveyed inst_nm rate apy zip msa cbsa county primarycompany

* Generate the 'month' variable (extract "YYYY-MM")
gen month = substr(datesurveyed, 1, 7)

* Rename original zip variable to zip_9digit
rename zip zip_9digit
* Extract the first five digits of the zip code and rename it zip_5digit
gen zip_5digit = substr(zip_9digit, 1, 5)
* Extract the first three digits of the zip code and name it zip_3digit
gen zip_3digit = substr(zip_9digit, 1, 3)

* Drop data from the year 2014
drop if substr(datesurveyed, 1, 4) == "2014"

***************************************
* 2. Save data for each product as a separate CSV file
***************************************
* Define product names (ensure they match the data)
local products "INTCK2.5K 12MCD10K SAV2.5K SAV25K"

cd "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/Mixed-Banking/Figures similar to Granja and Paixo Uniform Pricing Paper/data/intermediate"

foreach prod of local products {
    preserve
        * Keep only rows where productdescription matches the current product
        keep if productdescription == "`prod'"
        
        count  
        if r(N) > 0 { 
            local prod_fixed = subinstr("`prod'", ".", "_", .)  // Replace "." with "_"
            display "✅ Found `r(N)' observations for `prod'. Exporting data..."
            export delimited using "`prod_fixed'_data.csv", replace
        } 
        else {
            display "⚠️ No matching data found for `prod'. Skipping export."
        }
    restore
}

***************************************
* 3. Run regressions for all products and save adjusted R² results for each month
***************************************
foreach prod of local products {
    display "⭐️ Running regressions for `prod'..."

    * Ensure the file name matches the saved CSV
    local prod_fixed = subinstr("`prod'", ".", "_", .)  

    * Load product data
    import delimited using "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/Mixed-Banking/Figures similar to Granja and Paixo Uniform Pricing Paper/data/intermediate/`prod_fixed'_data.csv", clear

    * Retrieve all unique values of 'month'
    levelsof month, local(months)

    * Close any potentially open handles
    capture postclose handle

    * Use a common temporary file to store regression results
    tempfile regresults
    postfile handle str10 month double r2_inst double r2_primarycompany double r2_zip9 double r2_zip5 double r2_zip3 double r2_msa double r2_cbsa double r2_county using "`regresults'", replace

    foreach m of local months {
        preserve
            keep if month == "`m'"
            count
            if r(N) >= 5 {
                * Ensure categorical variables are properly encoded (including county and primarycompany)
                foreach var in inst_nm zip_9digit zip_5digit zip_3digit msa cbsa county primarycompany {
                    capture confirm numeric variable `var'
                    if _rc {
                        encode `var', gen(`var'_num)
                        drop `var'
                        rename `var'_num `var'
                    }
                }
                
                * Regression 1: Bank fixed effects using inst_nm (r2_inst)
                quietly regress rate i.inst_nm
                local r2_inst = e(r2_a)
                
                * Regression 2: Bank fixed effects using primarycompany
                quietly regress rate i.primarycompany
                local r2_primarycompany = e(r2_a)
                
                * Regression 3: ZIP-9 fixed effects
                quietly regress rate i.zip_9digit
                local r2_zip9 = e(r2_a)

                * Regression 4: ZIP-5 fixed effects
                quietly regress rate i.zip_5digit
                local r2_zip5 = e(r2_a)

                * Regression 5: ZIP-3 fixed effects
                quietly regress rate i.zip_3digit
                local r2_zip3 = e(r2_a)
                
                * Regression 6: MSA fixed effects
                quietly regress rate i.msa
                local r2_msa = e(r2_a)
                
                * Regression 7: CBSA fixed effects
                quietly regress rate i.cbsa
                local r2_cbsa = e(r2_a)

                * Regression 8: County fixed effects
                quietly regress rate i.county
                local r2_county = e(r2_a)
                
                * Save adjusted R² results for the current month
                post handle ("`m'") (`r2_inst') (`r2_primarycompany') (`r2_zip9') (`r2_zip5') (`r2_zip3') (`r2_msa') (`r2_cbsa') (`r2_county')
            }
            else {
                display "⚠️ Skipping month `m' due to insufficient observations (`r(N)')."
            }
        restore
    }

    postclose handle

    * Load saved results and export to a CSV file
    use `regresults', clear
    export delimited using "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/Mixed-Banking/Figures similar to Granja and Paixo Uniform Pricing Paper/data/intermediate/`prod_fixed'_reg_results.csv", replace

    display "✅ Regression results for `prod' saved!"
}
