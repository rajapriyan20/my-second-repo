%macro export_fill_rates(
    lib      = WORK,                             /* Library containing your dataset */
    dataset  = YOUR_TABLE_NAME,                 /* Name of your dataset */
    out_csv  = /your/target/path/fill_rates.csv /* Full destination path */
);

    /* 1. Extract metadata for all 480 columns */
    proc contents data=&lib..&dataset out=work._col_meta(keep=name type varnum) noprint;
    run;

    proc sort data=work._col_meta;
        by varnum;
    run;

    /* 2. Separate numeric and character variable lists */
    proc sql noprint;
        select name into :num_vars separated by ' ' from work._col_meta where type = 1;
        select count(*) into :n_num trimmed from work._col_meta where type = 1;
        
        select name into :char_vars separated by ' ' from work._col_meta where type = 2;
        select count(*) into :n_char trimmed from work._col_meta where type = 2;
    quit;

    /* 3. Compute non-missing counts in a single I/O pass */
    data work.fill_rate_summary(keep=Column_Name Total_Rows Non_Missing_Rows Missing_Rows Fill_Rate_Pct);
        length Column_Name $32;
        set &lib..&dataset end=_eof_;
        
        /* Process numeric columns */
        %if &n_num > 0 %then %do;
            array _nums[*] &num_vars;
            array _cnt_n[&n_num] _temporary_;
            do _i = 1 to dim(_nums);
                _cnt_n[_i] + (not missing(_nums[_i]));
            end;
        %end;

        /* Process character columns */
        %if &n_char > 0 %then %do;
            array _chars[*] &char_vars;
            array _cnt_c[&n_char] _temporary_;
            do _j = 1 to dim(_chars);
                _cnt_c[_j] + (not missing(_chars[_j]));
            end;
        %end;

        /* Output summary metrics at end-of-file */
        if _eof_ then do;
            Total_Rows = _N_;
            format Fill_Rate_Pct 8.2;
            
            %if &n_num > 0 %then %do;
                do _i = 1 to &n_num;
                    Column_Name      = vname(_nums[_i]);
                    Non_Missing_Rows = _cnt_n[_i];
                    Missing_Rows     = Total_Rows - Non_Missing_Rows;
                    Fill_Rate_Pct    = (Non_Missing_Rows / Total_Rows) * 100;
                    output;
                end;
            %end;

            %if &n_char > 0 %then %do;
                do _j = 1 to &n_char;
                    Column_Name      = vname(_chars[_j]);
                    Non_Missing_Rows = _cnt_c[_j];
                    Missing_Rows     = Total_Rows - Non_Missing_Rows;
                    Fill_Rate_Pct    = (Non_Missing_Rows / Total_Rows) * 100;
                    output;
                end;
            %end;
        end;
    run;

    /* 4. Sort results descending by fill rate */
    proc sort data=work.fill_rate_summary;
        by descending Fill_Rate_Pct;
    run;

    /* 5. Export summary to CSV */
    proc export data=work.fill_rate_summary
        outfile="&out_csv"
        dbms=csv
        replace;
    run;

    /* Clean up temporary tables */
    proc datasets lib=work nolist;
        delete _col_meta;
    quit;

%mend export_fill_rates;

/* Execute macro */
%export_fill_rates(
    lib      = WORK, 
    dataset  = YOUR_DATASET_NAME, 
    out_csv  = /your/target/path/fill_rates.csv
);
