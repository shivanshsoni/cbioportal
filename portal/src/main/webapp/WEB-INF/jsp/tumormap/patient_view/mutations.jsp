<%--
 - Copyright (c) 2015 Memorial Sloan-Kettering Cancer Center.
 -
 - This library is distributed in the hope that it will be useful, but WITHOUT
 - ANY WARRANTY, WITHOUT EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS
 - FOR A PARTICULAR PURPOSE. The software and documentation provided hereunder
 - is on an "as is" basis, and Memorial Sloan-Kettering Cancer Center has no
 - obligations to provide maintenance, support, updates, enhancements or
 - modifications. In no event shall Memorial Sloan-Kettering Cancer Center be
 - liable to any party for direct, indirect, special, incidental or
 - consequential damages, including lost profits, arising out of the use of this
 - software and its documentation, even if Memorial Sloan-Kettering Cancer
 - Center has been advised of the possibility of such damage.
 --%>

<%--
 - This file is part of cBioPortal.
 -
 - cBioPortal is free software: you can redistribute it and/or modify
 - it under the terms of the GNU Affero General Public License as
 - published by the Free Software Foundation, either version 3 of the
 - License.
 -
 - This program is distributed in the hope that it will be useful,
 - but WITHOUT ANY WARRANTY; without even the implied warranty of
 - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 - GNU Affero General Public License for more details.
 -
 - You should have received a copy of the GNU Affero General Public License
 - along with this program.  If not, see <http://www.gnu.org/licenses/>.
--%>

<%@ page import="org.mskcc.cbio.portal.servlet.PatientView" %>
<%@ page import="org.mskcc.cbio.portal.servlet.MutationsJSON" %>
<%@ page import="org.mskcc.cbio.portal.dao.DaoMutSig" %>

<script type="text/javascript" src="js/lib/igv_webstart.js?<%=GlobalProperties.getAppVersion()%>"></script>
<script type="text/javascript" src="js/src/patient-view/PancanMutationHistogram.js?<%=GlobalProperties.getAppVersion()%>"></script>

<link href="css/mutationMapper.min.css?<%=GlobalProperties.getAppVersion()%>" type="text/css" rel="stylesheet"/>

<style type="text/css" title="currentStyle">
    .oncokb-qtip {
        max-width: 800px !important;
    }
    .oncokb-qtip-sm {
        max-width: 400px !important;
    }
</style>
<script type="text/javascript">
    var mutTableIndices =
            ["id","case_ids","gene","aa","chr","start","end","ref","_var","validation","type",
             "tumor_freq","tumor_var_reads","tumor_ref_reads","norm_freq","norm_var_reads",
             "norm_ref_reads","bam","cna","mrna","altrate","pancan_mutations", "cosmic","ma","drug", "oncokb"];

    mutTableIndices = cbio.util.arrayToAssociatedArrayIndices(mutTableIndices);
    
    _.templateSettings = {
        interpolate : /\{\{(.+?)\}\}/g
    };
    
    var oncoKBDataInject = function(oTable, tableId) {
        if(!OncoKB.accessible) {
            accessOncoKB(function(){
                if(!OncoKB.dataReady) {
                    getOncoKBEvidence(oTable, tableId);
                }else {
                    addOncoKBListener(oTable, tableId);
                }
            });
        }else{
            if(!OncoKB.dataReady) {
                getOncoKBEvidence(oTable, tableId);
            }else {
                addOncoKBListener(oTable, tableId);
            }
        }
    };

    var drawPanCanThumbnails = function(oTable) {
        genomicEventObs.subscribePancanMutationsFrequency(function() {
            $(oTable).find('.pancan_mutations_histogram_wait').remove();
            $(oTable).find('.pancan_mutations_histogram_count').each(function() {
                if ($(this).hasClass("initialized")) return;
                $(this).addClass("initialized");
                var keyword = $(this).attr('keyword');
                var gene = $(this).attr('gene');
                $(this).html(genomicEventObs.pancan_mutation_frequencies.countByKey(keyword));
                $(this).qtip({
                    content: {text: 'pancancer mutation bar chart is broken'},
                    events: {
                        render: function(event, api) {
                            var byKeywordData = genomicEventObs.pancan_mutation_frequencies.data[keyword];
                            var byHugoData = genomicEventObs.pancan_mutation_frequencies.data[gene];
                            var invisible_container = document.getElementById("pancan_mutations_histogram_container");
                            var histogram = PancanMutationHistogram(byKeywordData, byHugoData, window.cancer_study_meta_data, invisible_container, {this_cancer_study: window.cancerStudyName});

                            var title = "<div><div><h3>"+gene+" mutations across all cancer studies</h3></div>" +
                                        "<div style='float:right;'><button class='cross-cancer-download' file-type='pdf'>PDF</button>"+
                                        "<button class='cross-cancer-download' file-type='svg'>SVG</button></div></div>"+
                                        "<div><p>"+histogram.overallCountText()+"</p></div>";
                            var content = title+invisible_container.innerHTML;
                            api.set('content.text', content);

                            // correct the qtip width
                            var svg_width = $(invisible_container).find('svg').attr('width');
                            $(this).css('max-width', parseInt(svg_width));

                            var this_svg = $(this).find('svg')[0];
                            histogram.qtip(this_svg);
                            
                            $(".cross-cancer-download").click(function() {
                                var fileType = $(this).attr("file-type");
	                            var filename = gene + "_mutations." + fileType;

	                            if (fileType == "pdf")
	                            {
		                            cbio.download.initDownload(this_svg, {
			                            filename: filename,
			                            contentType: "application/pdf",
			                            servletName: "svgtopdf.do"
		                            });
	                            }
	                            else // svg
	                            {
		                            cbio.download.initDownload(this_svg, {
			                            filename: filename
		                            });
	                            }
                            });

                            $(invisible_container).empty();     // N.B.
                        }
                    },
                    hide: { fixed: true, delay: 100 },
                    style: { classes: 'qtip-light qtip-rounded qtip-shadow', tip: true },
                    position: {my:'center right',at:'center left',viewport: $(window)}
                });
            });
        });
    };
    
    function getOncoKBEvidence(oTable, tableId) {
        var tumorType = '';
        if(Object.keys(clinicalDataMap).length > 0 && clinicalDataMap[Object.keys(clinicalDataMap)[0]].CANCER_TYPE){
            tumorType = clinicalDataMap[Object.keys(clinicalDataMap)[0]].CANCER_TYPE;
        }
        OncoKBConnector.getEvidence({
            mutations: genomicEventObs.mutations,
            tumorType: tumorType
        }, function(data) {
            if(data && data.length > 0) {
                genomicEventObs.mutations.addData("oncokb", data);
                OncoKB.dataReady = true;
            }
            addOncoKBListener(oTable, tableId);
        });
    }
    
    function buildMutationsDataTable(mutations,mutEventIds, table_id, sDom, iDisplayLength, sEmptyInfo, compact) {
        var data = [];
        for (var i=0, nEvents=mutEventIds.length; i<nEvents; i++) {
                data.push([mutEventIds[i]]);
        }
        var oTable = $("#"+table_id).dataTable( {
                "sDom": sDom, // selectable columns
                "oColVis": { "aiExclude": [ mutTableIndices["id"] ] }, // always hide id column
                "bJQueryUI": true,
                "bDestroy": true,
                "aaData": data,
                "aoColumnDefs":[
                    {// event id
                        "aTargets": [ mutTableIndices["id"] ],
                        "bVisible": false,
                        "mData" : 0
                    },
                    {// case_ids
                        "aTargets": [ mutTableIndices["case_ids"] ],
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "bVisible": caseIds.length>1,
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var samples = mutations.getValue(source[0], "caseIds");
                                var ret = [];
                                for (var i=0, n=caseIds.length; i<n; i++) {
                                    var caseId = caseIds[i];
                                    if ($.inArray(caseId,samples)>=0) {
                                        ret.push("<svg width='12' height='12' class='"
                                            +table_id+"-case-label' alt='"+caseId+"'></svg>");
                                    } else {
                                        ret.push("<svg width='12' height='12'></svg>");
                                    }
                                }
                                
                                return "<div>"+ret.join("&nbsp;")+"</div>";
                            } else if (type==='sort') {
                                var samples = mutations.getValue(source[0], "caseIds");
                                var ix = [];
                                samples.forEach(function(caseId){
                                    ix.push(caseMetaData.index[caseId]);
                                });
                                ix.sort();
                                var ret = 0;
                                for (var i=0; i<ix.length; i++) {
                                    ret += Math.pow(10,i)*ix[i];
                                }
                                return ret;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return mutations.getValue(source[0], "caseIds");
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// gene
                        "aTargets": [ mutTableIndices["gene"] ],
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var gene = mutations.getValue(source[0], "gene");
                                var entrez = mutations.getValue(source[0], "entrez");
//                                var tip = "<a href=\"http://www.ncbi.nlm.nih.gov/gene/"
//                                    +entrez+"\">NCBI Gene</a>";
//                                var sanger = mutations.getValue(source[0], 'sanger');
//                                if (sanger) {
//                                    tip += "<br/><a href=\"http://cancer.sanger.ac.uk/cosmic/gene/overview?ln="
//                                        +gene+"\">Sanger Cancer Gene Census</a>";
//                                }
                                var ret = "<b>"+gene+"</b>";
//                                if (tip) {
                                ret = "<span class='"+table_id+"-tip oncokb oncokb_gene' gene='"+gene+"' hashId='"+source[0]+"'>"+ret+"</span>";
//                                }
                                ret += "<img width='12' height='12' class='loader' src='images/ajax-loader.gif'/>";

                                return ret;
                            } else {
                                return mutations.getValue(source[0], "gene");
                            }
                        }
                    },
                    {// aa change
                        "aTargets": [ mutTableIndices["aa"] ],
                        "sClass": "no-wrap-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var aa = mutations.getValue(source[0], 'aa');
                                if (aa.length>2&&aa.substring(0,2)=='p.')
                                    aa = aa.substring(2);
                                var ret = "<b><i>"+aa+"</i></b>";
                                if (mutations.getValue(source[0],'status')==="Germline")
                                    ret += "&nbsp;<span style='background-color:red;font-size:x-small;' class='"
                                            +table_id+"-tip' alt='Germline mutation'>Germline</span>";
                                ret += "<span class='oncokb oncokb_alteration hotspot' alteration='"+aa+"' hashId='"+source[0]+"' style='display:none;margin-left:5px;'><img width='13' height='13' src='images/oncokb-flame.svg'></span>";
                                ret += "&nbsp;<span class='oncokb oncokb_alteration oncogenic' alteration='"+aa+"' hashId='"+source[0]+"' style='display:none'><img class='oncogenic' width='13' height='13' src='images/oncokb-oncogenic-1.svg' style='display:none'><img class='unknownoncogenic' width='13' height='13' src='images/oncokb-oncogenic-2.svg' style='display:none'><img class='notoncogenic' width='13' height='13' src='images/oncokb-oncogenic-3.svg' style='display:none'></span><img width='13' height='13' class='loader' src='images/ajax-loader.gif'/>";
                                    var mcg = mutations.getValue(source[0], 'mycancergenome');
                                    if (!cbio.util.checkNullOrUndefined(mcg) && mcg.length) {
                                        ret += "&nbsp;<span class='"+table_id+"-tip'" +
		                                   "alt='MyCancerGenome.org links:<br/><ul style=\"list-style-position: inside;padding-left:0;\"><li>"+mcg.join("</li><li>")+"</li></ul>'>" +
		                                   "<img src='images/mcg_logo.png'></span>";
                                    }

	                            var aaOriginal = mutations.getValue(source[0], 'aa-orig');

	                            if (window.cancerStudyId.indexOf("mskimpact") !== -1 &&
	                                isDifferentProteinChange(aa, aaOriginal))
	                            {
		                            ret += "&nbsp;<span class='"+table_id+"-tip'" +
		                                   "alt='The original annotation file indicates a different value: <b>"+normalizeProteinChange(aaOriginal)+"</b>'>" +
		                                   "<img class='mutationsProteinChangeWarning' height=13 width=13 src='images/warning.gif'></span>";
	                            }

                                return ret;
                            } else {
                                return mutations.getValue(source[0], 'aa');
                            }
                        },
                        "bSortable" : false
                    },
                    {// chr
                        "aTargets": [ mutTableIndices["chr"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return mutations.getValue(source[0], 'chr');
                            } else {
                                return mutations.getValue(source[0], 'chr');
                            }
                        }
                    },
                    {// start
                        "aTargets": [ mutTableIndices["start"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return mutations.getValue(source[0], 'start');
                            } else {
                                return mutations.getValue(source[0], 'start');
                            }
                        },
                        "bSortable" : false
                    },
                    {// end
                        "aTargets": [ mutTableIndices["end"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return mutations.getValue(source[0], 'end');
                            } else {
                                return mutations.getValue(source[0], 'end');
                            }
                        },
                        "bSortable" : false
                    },
                    {// ref
                        "aTargets": [ mutTableIndices["ref"] ],
                        "bVisible": false,
                        "sClass": "center-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return mutations.getValue(source[0], 'ref');
                            } else {
                                return mutations.getValue(source[0], 'ref');
                            }
                        }
                    },
                    {// var
                        "aTargets": [ mutTableIndices["_var"] ],
                        "bVisible": false,
                        "sClass": "center-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return mutations.getValue(source[0], 'var');
                            } else {
                                return mutations.getValue(source[0], 'var');
                            }
                        }
                    },
                    {// validation
                        "bVisible": false,
                        "aTargets": [ mutTableIndices["validation"] ],
                        "sClass": "no-wrap-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else {
                                var val = mutations.getValue(source[0],'validation');
                                return val ? val : "";
                            }
                        }
                    },
                    {// type
                        "aTargets": [ mutTableIndices["type"] ],
                        "sClass": "center-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display'||type==='filter') {
                                var mutType = mutations.getValue(source[0], "type");
                                var abbr, color;
                                if (mutType==='Missense_Mutation'||mutType==='missense') {
                                    abbr = 'Missense';
                                    color = 'green';
                                } else if (mutType==='Nonsense_Mutation') {
                                    abbr = 'Nonsense';
                                    color = 'red';
                                } else if (mutType==='Splice_Site') {
                                    abbr = 'Splice Site';
                                    color = 'red';
                                } else if (mutType==='In_Frame_Ins') {
                                    abbr = 'Insertion';
                                    color = 'black';
                                } else if (mutType==='In_Frame_Del') {
                                    abbr = 'Deletion';
                                    color = 'black';
                                } else if (mutType==='Fusion') {
                                    abbr = 'Fusion';
                                    color = 'black';
                                } else if (mutType==='Frame_Shift_Del') {
                                    abbr = 'Frameshift';
                                    color = 'red';
                                } else if (mutType==='Frame_Shift_Ins') {
                                    abbr = 'Frameshift';
                                    color = 'red';
                                } else if (mutType==='RNA') {
                                    abbr = 'RNA';
                                    color = 'green';
                                } else if (mutType==='Nonstop_Mutation') {
                                    abbr = 'Nonstop';
                                    color = 'red';
                                } else if (mutType==='Translation_Start_Site') {
                                    abbr = 'Translation Start Site';
                                    color = 'green';
                                } else {
                                    abbr = mutType;
                                    color = 'gray';
                                }
                                
                                if (type==='filter') return abbr;
                                
                                return "<span style='color:"+color+";' class='"
                                            +table_id+"-tip' alt='"+mutType+"'><b>"
                                            +abbr+"</b></span>";
                            } else {
                                return mutations.getValue(source[0], "type");
                            }
                        }
                        
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["tumor_freq"] ],
                        "bVisible": hasAlleleFrequencyData,
                        "sClass": "center-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var refCount = mutations.getValue(source[0], 'ref-count');
                                var altCount = mutations.getValue(source[0], 'alt-count');
                                if (caseIds.length===1) {
                                    var ac = altCount[caseIds[0]];
                                    var rc = refCount[caseIds[0]];
                                    if (cbio.util.checkNullOrUndefined(ac)||cbio.util.checkNullOrUndefined(rc)) return "";
                                    var freq = ac / (ac + rc);
                                    var tip = ac + " variant reads out of " + (rc+ac) + " total";
                                    return "<span class='"+table_id+"-tip' alt='"+tip+"'>"+freq.toFixed(2)+"</span>";
                                }
                                
                                if ($.isEmptyObject(refCount)||$.isEmptyObject(altCount))
                                    return "";
                                return "<div class='"+table_id+"-tumor-freq' alt='"+source[0]+"'></div>";
                            } else if (type==='sort') {
                                var refCount = mutations.getValue(source[0], 'ref-count')[caseIds[0]];
                                var altCount = mutations.getValue(source[0], 'alt-count')[caseIds[0]];
                                if (!altCount&&!refCount) return 0;
                                return altCount / (altCount + refCount);
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["tumor_var_reads"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var altCount = mutations.getValue(source[0], 'alt-count');
                                if (caseIds.length===1) return altCount[caseIds[0]]?altCount[caseIds[0]]:"";
                                
                                var arr = [];
                                for (var ac in altCount) {
                                    arr.push(ac+": "+altCount[ac].toFixed(2));
                                } 
                                return arr.join("<br/>")
                            } else if (type==='sort') {
                                var altCount = mutations.getValue(source[0], 'alt-count')[caseIds[0]];
                                if (!altCount) return 0;
                                return altCount;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["tumor_ref_reads"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var altCount = mutations.getValue(source[0], 'ref-count');
                                if (caseIds.length===1) return altCount[caseIds[0]]?altCount[caseIds[0]]:"";
                                
                                var arr = [];
                                for (var ac in altCount) {
                                    arr.push(ac+": "+altCount[ac].toFixed(2));
                                } 
                                return arr.join("<br/>")
                            } else if (type==='sort') {
                                var refCount = mutations.getValue(source[0], 'ref-count')[caseIds[0]];
                                if (!refCount) return 0;
                                return refCount;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// normal read count frequency
                        "aTargets": [ mutTableIndices["norm_freq"] ],
                        "bVisible": !compact&&hasAlleleFrequencyData,
                        "sClass": caseIds.length>1 ? "center-align-td":"right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var refCount = mutations.getValue(source[0], 'normal-ref-count');
                                var altCount = mutations.getValue(source[0], 'normal-alt-count');
                                if (caseIds.length===1) {
                                    var ac = altCount[caseIds[0]];
                                    var rc = refCount[caseIds[0]];
                                    if (!ac&&!rc) return "";
                                    var freq = ac / (ac + rc);
                                    var tip = ac + " variant reads out of " + (rc+ac) + " total";
                                    return "<span class='"+table_id+"-tip' alt='"+tip+"'>"+freq.toFixed(2)+"</span>";
                                }
                                
                                if ($.isEmptyObject(refCount)||$.isEmptyObject(altCount))
                                    return "";
                                return "<div class='"+table_id+"-normal-freq' alt='"+source[0]+"'></div>"; 
                            } else if (type==='sort') {
                                var refCount = mutations.getValue(source[0], 'normal-ref-count')[caseIds[0]];
                                var altCount = mutations.getValue(source[0], 'normal-alt-count')[caseIds[0]];
                                if (!altCount&&!refCount) return 0;
                                return altCount / (altCount + refCount);
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["norm_var_reads"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var altCount = mutations.getValue(source[0], 'normal-alt-count');
                                if (caseIds.length===1) return altCount[caseIds[0]]?altCount[caseIds[0]]:"";
                                
                                var arr = [];
                                for (var ac in altCount) {
                                    arr.push(ac+": "+altCount[ac].toFixed(2));
                                } 
                                return arr.join("<br/>")
                            } else if (type==='sort') {
                                var altCount = mutations.getValue(source[0], 'normal-alt-count')[caseIds[0]];
                                if (!altCount) return 0;
                                return altCount;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["norm_ref_reads"] ],
                        "bVisible": false,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var altCount = mutations.getValue(source[0], 'normal-ref-count');
                                if (caseIds.length===1) return altCount[caseIds[0]]?altCount[caseIds[0]]:"";
                                
                                var arr = [];
                                for (var ac in altCount) {
                                    arr.push(ac+": "+altCount[ac].toFixed(2));
                                } 
                                return arr.join("<br/>")
                            } else if (type==='sort') {
                                var refCount = mutations.getValue(source[0], 'normal-ref-count')[caseIds[0]];
                                if (!refCount) return 0;
                                return refCount;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return 0.0;
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// tumor read count frequency
                        "aTargets": [ mutTableIndices["bam"] ],
                        "bVisible": false,//viewBam,
                        "sClass": "right-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else {
                                var samples = mutations.getValue(source[0], "caseIds");
                                var chr = mutations.getValue(source[0], "chr");
                                var start = mutations.getValue(source[0], "start");
                                var end = mutations.getValue(source[0], "end");
                                var ret = [];
                                for (var i=0, n=samples.length; i<n; i++) {
                                    if (mapCaseBam[samples[i]]) {
                                        ret.push('<a class="igv-link" alt="igvlinking.json?cancer_study_id'
                                                +'=prad_su2c&case_id='+samples[i]+'&locus=chr'+chr+'%3A'+start+'-'+end+'">'
                                                +'<span style="background-color:#88C;color:white">&nbsp;IGV&nbsp;</span></a>');
                                    }
                                }
                                return ret.join("&nbsp;");
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// cna
                        "aTargets": [ mutTableIndices['cna'] ],
                        "bVisible": !mutations.colAllNull('cna'),
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "mDataProp": 
                            function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var cna = mutations.getValue(source[0], 'cna');
                                switch (cna) {
                                    case "-2": return "<span style='color:blue;' class='"
                                           +table_id+"-tip' alt='Deep deletion'><b>DeepDel</b></span>";
                                    case "-1": return "<span style='color:blue;font-size:smaller;' class='"
                                           +table_id+"-tip' alt='Shallow deletion'><b>ShallowDel</b></span>";
                                    case "0": return "<span style='color:black;font-size:xx-small;' class='"
                                           +table_id+"-tip' alt='Diploid / normal'>Diploid</span>";
                                    case "1": return "<span style='color:red;font-size:smaller;' class='"
                                           +table_id+"-tip' alt='Low-level gain'><b>Gain</b></span>";
                                    case "2": return "<span style='color:red;' class='"
                                           +table_id+"-tip' alt='High-level amplification'><b>Amp</b></span>";
                                    default: return "<span style='color:gray;font-size:xx-small;' class='"
                                           +table_id+"-tip' alt='CNA data is not available for this gene.'>NA</span>";
                                }
                            } else if (type==='sort') {
                                var cna = mutations.getValue(source[0], 'cna');
                                return cna?cna:0;
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return '';
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// mrna
                        "aTargets": [ mutTableIndices['mrna'] ],
                        "bVisible": !mutations.colAllNull('mrna'),
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "mDataProp": 
                            function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var mrna = mutations.getValue(source[0], 'mrna');
                                if (mrna===null) return "<span style='color:gray;font-size:xx-small;' class='"
                                           +table_id+"-tip' alt='mRNA data is not available for this gene.'>NA</span>";
                                return "<div class='"+table_id+"-mrna' alt='"+source[0]+"'></div>";
                            } else if (type==='sort') {
                                var mrna = mutations.getValue(source[0], 'mrna');
                                return mrna ? mrna['perc'] : 50;
                            } else if (type==='type') {
                                    return 0.0;
                            } else {
                                return '';
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// gene mutation rate
                        "aTargets": [ mutTableIndices["altrate"] ],
                        "sClass": "center-align-td",
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                return "<div class='"+table_id+"-mut-cohort' alt='"+source[0]+"'></div>";
                            } else if (type==='sort') {
                                return mutations.getValue(source[0], 'genemutrate');
                            } else if (type==='type') {
                                return 0.0;
                            } else {
                                return mutations.getValue(source[0], 'genemutrate');
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// pancan mutations
                        "aTargets": [ mutTableIndices["pancan_mutations"] ],
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "mDataProp": function(source,type,value) {
                            if (type === 'display') {
                                var keyword = mutations.getValue(source[0], "key");
                                var hugo = mutations.getValue(source[0], "gene");

                                var ret = "<div class='pancan_mutations_histogram_thumbnail' gene='"+hugo+"' keyword='"+keyword+"'></div>";
                                    ret += "<img width='15' height='15' class='pancan_mutations_histogram_wait' src='images/ajax-loader.gif'/>";
                                    ret += "<div class='pancan_mutations_histogram_count' style='float:right' gene='"+hugo+"' keyword='"+keyword+"'></div>";
                                    
                                return ret;
                            }
                            else if (type === "sort") {
                                if (genomicEventObs.pancan_mutation_frequencies) {
                                    var key = mutations.getValue(source[0], "key");
                                    return genomicEventObs.pancan_mutation_frequencies.countByKey(key);
                                } else {
                                    return 0;
                                }
                            }
                            else if (type === "type") {
                                return 0.0;
                            }

                            return "";
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {// cosmic
                        "aTargets": [ mutTableIndices["cosmic"] ],
                        "sClass": "right-align-td",
                        "asSorting": ["desc", "asc"],
                        "bSearchable": false,
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var cosmic = mutations.getValue(source[0], 'cosmic');
                                if (!cosmic) return "";
                                var arr = [];
                                var n = 0;
                                cosmic.forEach(function(c) {
                                    arr.push("<td>"+c[0]+"</td><td>"+c[1]+"</td><td>"+c[2]+"</td>");
                                    n += c[2];
                                });
                                if (n===0) return "";
                                var tip = '<b>'+n+' occurrences of '+mutations.getValue(source[0], 'key')
                                    +' mutations in COSMIC</b><br/><table class="'+table_id
                                    +'-cosmic-table uninitialized"><thead><th>COSMIC ID</th><th>Protein Change</th><th>Occurrence</th></thead><tbody><tr>'
                                    +arr.join('</tr><tr>')+'</tr></tbody></table>';
                                return  "<span class='"+table_id
                                                +"-cosmic-tip' alt='"+tip+"'>"+n+"</span>";
                            } else if (type==='sort') {
                                var cosmic = mutations.getValue(source[0], 'cosmic');
                                var n = 0;
                                if (cosmic) {
                                    cosmic.forEach(function(c) {
                                        n += c[2];
                                    });
                                }
                                return n;
                            } else if (type==='type') {
                                return 0;
                            } else {
                                return mutations.getValue(source[0], 'cosmic');
                            }
                        }
                    },
                    {// drugs
                        "aTargets": [ mutTableIndices["drug"] ],
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "bVisible": false,
                        "mDataProp": 
                            function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var drug = mutations.getValue(source[0], 'drug');
                                if (!drug) return '';
                                var len = drug.length;
                                if (len===0) return '';
                                return "<img src='images/drug.png' width=12 height=12 id='"
                                            +table_id+'_'+source[0]+"-drug-tip' class='"
                                            +table_id+"-drug-tip' alt='"+drug.join(',')+"'>";
                            } else if (type==='sort') {
                                var drug = mutations.getValue(source[0], 'drug');
                                return drug ? drug.length : 0;
                            } else if (type==='type') {
                                return 0;
                            } else {
                                var drug = mutations.getValue(source[0], 'drug');
                                return drug ? drug : '';
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },
                    {
                        "aTargets": [ mutTableIndices["ma"] ],
                        "sClass": "center-align-td",
                        "bVisible": false,
                        "mDataProp": function(source,type,value) {
                            if (type==='set') {
                                return;
                            } else if (type==='display') {
                                var ma = mutations.getValue(source[0], 'ma');
                                
                                var score = ma['score'];
                                var maclass,impact;
                                if (score==='N') {maclass="oma_link oma_neutral"; impact='Neutral';}
                                else if (score==='L') {maclass="oma_link oma_low"; impact='Low';}
                                else if (score==='M') {maclass="oma_link oma_medium"; impact='Medium';}
                                else if (score==='H') {maclass="oma_link oma_high"; impact='High';}
                                
                                var ret = "";
                                if (impact) {
                                    var tip = "";
                                    var xvia = ma['xvia'];
                                    if (xvia!=null) {
                                        if (xvia.indexOf('http://')!==0) xvia='http://'+xvia;
                                        xvia = xvia.replace("getma.org", "mutationassessor.org");
                                        tip += "<div class=\"mutation-assessor-main-link mutation-assessor-link\">" +
                                                "<a href=\""+xvia+"\" target=\"_blank\"><img height=\"15\" width=\"19\" src=\"images/ma.png\"> Go to Mutation Assessor</a></div>";
                                    }
                                    
                                    var msa = ma['msa'];
                                    if (msa&&msa!=='NA') {
                                        if (msa.indexOf('http://')!==0) msa='http://'+msa;
                                        msa=msa.replace("getma.org", "mutationassessor.org");
                                        tip += "<div class=\"mutation-assessor-msa-link mutation-assessor-link\">"+
                                               "<a href=\""+msa+"\" target=\"_blank\"><span class=\"ma-msa-icon\">msa</span> Multiple Sequence Alignment</a></div>";
                                    }
                                    
                                    var pdb = ma['pdb'];
                                    if (pdb&&pdb!=='NA') {
                                        pdb=pdb.replace("getma.org", "mutationassessor.org");
                                        if (pdb.indexOf('http://')!==0) pdb='http://'+pdb;
                                        tip += "<div class=\"mutation-assessor-3d-link mutation-assessor-link\">"+
                                               "<a href=\""+pdb+"\" target=\"_blank\"><span class=\"ma-3d-icon\">3D</span> Mutation Assessor 3D View</a></div>";
                                    }

                                    ret += "<span class='"+maclass+" "+table_id+"-ma-tip' alt='"+tip+"'>"+impact+"</span>";
                                }
                                
                                return ret;
                            } else if (type==='sort') {
                                var ma = mutations.getValue(source[0], 'ma');
                                var score = ma['score'];
                                if (score==='N') return '0';
                                else if (score==='L') return '1';
                                else if (score==='M') return '2';
                                else if (score==='H') return '3';
                                else return '-1';
                            } else if (type==='filter') {
                                var ma = mutations.getValue(source[0], 'ma');
                                var score = ma['score'];
                                if (score==='N'||score==='L'||score==='M'||score==='H') return score;
                                else return '';
                            } else {
                                return mutations.getValue(source[0], 'ma');
                            }
                        },
                        "asSorting": ["desc", "asc"]
                    },{// OncoKB column
                        "aTargets": [ mutTableIndices["oncokb"] ],
                        "sClass": "center-align-td",
                        "bSearchable": false,
                        "bSortable" : false,
                        "bVisible": OncoKB.accessible,
                        "mDataProp":
                            function(source,type,value) {
                                if (type==='set') {
                                    return;
                                } else if (type==='display') {
                                    var ret = "<span class='oncokb oncokb_column' hashId='"+source[0]+"' style='display:none'></span><img width='13' height='13' class='loader' src='images/ajax-loader.gif'/>";
                                    return ret;
                                } else {
                                    return '';
                                }
                            }
                    }
                ],
                "fnDrawCallback": function( oSettings ) {
                    if (caseIds.length>1) {
                        plotCaseLabel('.'+table_id+'-case-label',true);
                        plotAlleleFreq("."+table_id+"-tumor-freq",mutations,"alt-count","ref-count");
                        plotAlleleFreq("."+table_id+"-normal-freq",mutations,"normal-alt-count","normal-ref-count");
                    }
                    plotMrna("."+table_id+"-mrna",mutations);
                    plotMutRate("."+table_id+"-mut-cohort",mutations);
                    addNoteTooltip("."+table_id+"-tip");
                    addNoteTooltip("."+table_id+"-ma-tip",null,{my:'top right',at:'bottom center',viewport: $(window)});
                    addDrugsTooltip("."+table_id+"-drug-tip", 'top right', 'bottom center');
                    addCosmicTooltip(table_id);
                    listenToBamIgvClick(".igv-link");
                    drawPanCanThumbnails(this);
                    oncoKBDataInject(this, table_id);
                },
                "bPaginate": true,
                "sPaginationType": "two_button",
                "aaSorting": [[mutTableIndices["cosmic"],'desc'],[mutTableIndices["altrate"],'desc']],
                "oLanguage": {
                    "sInfo": "&nbsp;&nbsp;(_START_ to _END_ of _TOTAL_)&nbsp;&nbsp;",
                    "sInfoFiltered": "",
                    "sLengthMenu": "Show _MENU_ per page",
                    "sEmptyTable": sEmptyInfo
                },
                "iDisplayLength": iDisplayLength,
                "aLengthMenu": [[5,10, 25, 50, 100, -1], [5, 10, 25, 50, 100, "All"]]
        } );

        oTable.css("width","100%");
        addNoteTooltip("#"+table_id+" th.mut-header");

//        genomicEventObs.subscribePancanMutationsFrequency(function() {
//            drawPanCanThumbnails(oTable);
//        });

        return oTable;
    }
    
    function addOncoKBListener(oTable, table_id){
        $(oTable).find('.oncokb_gene').each(function() {
            if(OncoKB.dataReady) {
                var hashId = $(this).attr('hashId');
                var gene = genomicEventObs.mutations.getValue(hashId, 'oncokb').gene;
                var _tip = '';

                if(gene.summary) {
                    _tip +=  '<b>Gene Summary</b><br/>' + gene.summary;
                }
                if(gene.background) {
                    _tip += '<br/><div><span class="oncokb_gene_moreInfo"><br/><a>More Info</a><i style="float:right">Powered by OncoKB(Beta)</i></span><br/><span class="oncokb_gene_background" style="display:none"><b>Gene Background</b><br/>' + gene.background + '<br/><i style="float:right">Powered by OncoKB(Beta)</i></span></div>';
                }
                if(_tip !== '') {
                    $(this).css('display', '');
                    $(this).qtip('destroy', true);
                    $(this).qtip({
                        content: {text: _tip},
                        hide: { fixed: true, delay: 100 },
                        style: { classes: 'qtip-light qtip-rounded qtip-shadow', tip: true },
                        position: {my:'center right',at:'center left',viewport: $(window)}
                    });
                }
            }
            $(this).parent().find('.loader').remove();
        });

        $(oTable).find('.oncokb_alteration').each(function() {
            if(OncoKB.dataReady) {
                var hashId = $(this).attr('hashId');
                var oncogenicIconColor = 'grey';

                //Change oncogenic icon color
                switch (genomicEventObs.mutations.getValue(hashId, 'oncokb').oncogenic) {
                    case 0:
                        $(this).find('.notoncogenic').css('display', '');
                        oncogenicIconColor = 'black';
                        break;
                    case -1:
                        $(this).find('.unknownoncogenic').css('display', '');
                        oncogenicIconColor = 'grey';
                        break;
                    case 2:
                        $(this).find('.oncogenic').css('display', '');
                        oncogenicIconColor = 'hotpink';
                        break;
                    case 1:
                        $(this).find('.oncogenic').css('display', '');
                        oncogenicIconColor = 'red';
                        break;
                }
                $(this).find('i.fa-dot-circle-o').css('color', oncogenicIconColor);

                if(genomicEventObs.mutations.getValue(hashId, 'oncokb').alteration.length >0) {
                    var _alterations = genomicEventObs.mutations.getValue(hashId, 'oncokb').alteration,
                            _variantSummary = genomicEventObs.mutations.getValue(hashId, 'oncokb').variantSummary,
                            _hotspot = genomicEventObs.mutations.getValue(hashId, 'oncokb').hotspot,
                            _tip = '', _oncogenicTip = '', _hotspotTip = '';
                    _oncogenicTip += _variantSummary + '<br/>';
                    if(_alterations && _alterations.length > 0) {
                        _oncogenicTip += '<div><span class="oncokb_alt_moreInfo"><br/><a>More Info</a></span><br/><span class="oncokb_mutation_effect" style="display:none">';
                        for(var i=0, altsL=_alterations.length; i<altsL; i++) {
                            _oncogenicTip += '<b>Mutation Effect: '+_alterations[i].knownEffect + '</b><br/>' + _alterations[i].description + '<br/>';
                        }
                        _oncogenicTip += '</span></div>';
                    }

                    if(_hotspot === 1){
                        _hotspotTip = 'This mutated amino acid was identified as a recurrent hotspot (statistical significance, q-value < 0.01) in a set of 11,119 tumor samples of various cancer types (based on Chang M. et al. Nature Biotech. 2015).'
                    }

//                    if (genomicEventObs.mutations.getValue(hashId, 'oncokb').oncogenic){
                    _oncogenicTip += '<span style="float:right"><i>Powered by OncoKB(Beta)</i></span><br/><br/><i>OncoKB is under development, please pardon errors and omissions. Please send feedback to <a href="mailto:oncokb@cbio.mskcc.org" title="Contact us">oncokb@cbio.mskcc.org</a></i>';
//                    }

                    if($(this).hasClass('oncogenic')) {
                        _tip = _oncogenicTip;
                    }else if($(this).hasClass('hotspot')) {
                        _tip = _hotspotTip;
                    }

                    if(_tip !== '') {
                        $(this).css('display', '');
                        $(this).qtip('destroy', true);
                        $(this).qtip({
                            content: {text: _tip},
                            hide: { fixed: true, delay: 100 },
                            style: { classes: 'qtip-light qtip-rounded qtip-shadow', tip: true },
                            position: {my:'center right',at:'center left',viewport: $(window)}
                        });
                    }
                }
            }
            $(this).parent().find('.loader').remove();
        });

        $(oTable).find('.oncokb_column').each(function() {
            if(OncoKB.dataReady) {
                var hashId = $(this).attr('hashId');

                if(genomicEventObs.mutations.getValue(hashId, 'oncokb')) {
                    var _prevalence = genomicEventObs.mutations.getValue(hashId, 'oncokb').prevalence,
                        _progImp = genomicEventObs.mutations.getValue(hashId, 'oncokb').progImp,
                        _trials = genomicEventObs.mutations.getValue(hashId, 'oncokb').trials,
                        _treatments = genomicEventObs.mutations.getValue(hashId, 'oncokb').treatments;
                    $(this).empty();
                    createOncoKBColumnCell(this, _prevalence, _progImp, _treatments, _trials);
                }
            }
            $(this).css('display', 'block');
            $(this).parent().find('.loader').remove();
        });

        $('.oncokb').hover(function(){
            $(".oncokb_gene_moreInfo").click(function() {
                $(this).css('display', 'none');
                $(this).parent().find('.oncokb_gene_background').css('display', 'block');
            });
            $(".oncokb_alt_moreInfo").click(function() {
                $(this).css('display', 'none');
                $(this).parent().find('.oncokb_mutation_effect').css('display', 'block');
            });
        });

        $('#oncokb-help').qtip({
            content: {text: oncokbHelpStr()},
            hide: { fixed: true, delay: 100 },
            style: { classes: 'qtip-light qtip-rounded qtip-shadow', tip: true },
            position: {my:'center right',at:'center left',viewport: $(window)}
        });
    }

    function oncokbHelpStr() {
        var levels = {
//            '0': 'FDA-approved drug in this indication irrespective of gene/variant biomarker.',
            '1': 'FDA-approved biomarker and drug association in this indication.',
            '2A': 'FDA-approved biomarker and drug association in another indication, and NCCN-compendium listed for this indication.',
            '2B': 'FDA-approved biomarker in another indication, but not FDA or NCCN-compendium-listed for this indication.',
            '3': 'Clinical evidence links this biomarker to drug response but no FDA-approved or NCCN compendium-listed biomarker and drug association.',
            '4': 'Preclinical evidence potentially links this biomarker to response but no FDA-approved or NCCN compendium-listed biomarker and drug association.',
            'R1': 'NCCN-compendium listed biomarker for resistance to a FDA-approved drug.',
            'R2': 'Not NCCN compendium-listed biomarker, but clinical evidence linking this biomarker to drug resistance.',
            'R3': 'Not NCCN compendium-listed biomarker, but preclinical evidence potentially linking this biomarker to drug resistance.'
        }
        var str = '<b>Level of therapeutic implications explanations:</b><br/>';

        for(var level in levels){
            str += '<b>' + level + '</b>: ' + levels[level] + '<br/>';
        }

        return str;
    }

    function createTreatmentsStr(treatments){
        var str = '', i;
        if(treatments instanceof Array) {
            var treatmentsL = treatments.length;
            str += '<table class="oncokb-treatments-datatable"><thead><tr><th>TREATMENTS</th><th>LEVEL</th><th>TUMOR TYPE</th><th>DESCRIPTION</th></tr></thead><tbody>';
            for(i = 0; i < treatmentsL; i++) {
                str += '<tr>';
                str += '<td>' + createDrugsStr(treatments[i].content) + '</td>';
                str += '<td>' + getLevel(treatments[i].level) + '</td>';
                str += '<td>' + treatments[i].tumorType + '</td>';
//                str += '<td>' + (treatments.length>2?shortDescription(treatments[i].description): treatments[i].description)+ '</td>';
                str += '<td>' + shortDescription(treatments[i].description)+ '</td>';
                str +='</tr>';
            }
            str += '</tbody>';
        }
        return str;
    }

    function getLevel(level){
        var _level = level.match(/LEVEL_(R?\d[AB]?)/);
        if(_level instanceof Array && _level.length >= 2){
            return _level[1];
        }else{
            return level;
        }
    }

    function createDrugsStr(drugs){
        var str = '', i, j;
        if(drugs instanceof Array) {
            var drugsL = drugs.length;
            for(i = 0; i < drugsL; i++){
                var _drugsL = drugs[i].drugs.length;

                for(j = 0; j < _drugsL; j++){
                    str += drugs[i].drugs[j].drugName;
                    if(j != _drugsL - 1) {
                        str += '+';
                    }
                }

                if(i != drugsL - 1) {
                    str += ', ';
                }
            }
        }
        return str;
    }

    function shortDescription(description) {
        var str = '';
        var threshold = 80;
        var shortStr = description.substring(0, threshold-8);
        //Need to identify <a> tag, you do not want to cut the string in mid of <a> tag
        var aIndex = {
            start: -1,
            end: -1
        };
        if(description && description.length > threshold){
            if(shortStr.indexOf('<a') !== -1) {
                aIndex.start = shortStr.indexOf('<a');
                if(shortStr.indexOf('</a>') !== -1 && shortStr.indexOf('</a>') < (threshold - 8 - 3)) {
                    aIndex.end = shortStr.indexOf('</a>');
                }
            }

            if(aIndex.start > -1){
                //Means the short description has part of <a> tag
                if(aIndex.end == -1) {
                    shortStr = description.substring(0, (aIndex.start));
                }
            }
            str = '<span><span class="oncokb-shortDescription">' + shortStr + '<span class="oncokb-description-more" >... <a>more</a></span></span>';
            str += '<span class="oncokb-fullDescription" style="display:none">' + description + '</span></span>';
        }else{
            str = '<span class="oncokb-fullDescriotion">' + description + '</span>';
        }

        return str;
    }

    /**
     *
     * @param array this is object array, the object should have tumorType and description attributes
     */
    function oncokbGetString(array, title, tableClass) {
        var str = '', i;
        if(array instanceof Array){
            var arrayL = array.length;
            str += '<table class="oncokb-'+tableClass+'-datatable"><thead><tr><th style="white-space:nowrap">TUMOR TYPE</th><th>' + title + '</th></tr></thead><tbody>';
            for(i = 0; i < arrayL; i++){
                    str += '<tr>';
                    str += '<td style="white-space:nowrap">' + array[i].tumorType + '</td>';
                    str += '<td>' + shortDescription(array[i].description)+ '</td>';
                    str +='</tr>';
            }
            str += '</tbody>';
        }
        return str;
    }

    function oncokbIcon(g,text,fill, fontSize) {
        g.append("rect")
                .attr("rx",'3')
                .attr("ry",'3')
                .attr('width', '14')
                .attr('height', '14')
                .attr("fill",fill);
        g.append("text")
                .attr('transform', 'translate(7, 11)')
                .attr('text-anchor', 'middle')
                .attr("font-size",fontSize)
                .attr('font-family', 'Sans-serif')
                .attr('stroke-width', 0)
                .attr("fill",'#ffffff')
                .text(text);
    }

    function oncokbLevelIcon(g,level, fill) {
        g.append("circle")
                .attr('transform', 'translate(13, 0)')
                .attr('r', '6')
                .attr("fill",fill);
        g.append("text")
                .attr('transform', 'translate(13, 3)')
                .attr('text-anchor', 'middle')
                .attr("font-size", '10')
                .attr('font-family', 'Sans-serif')
                .attr('stroke-width', 0)
                .attr("fill",'#ffffff')
                .text(level);
    }

    function createOncoKBAlterationCell(target, alterations) {
        var altsL = alterations.length, i, tip = '';
        if(altsL > 0) {
            var svg = d3.select($(target)[0])
                    .append("svg")
                    .attr("width", 13)
                    .attr("height", 13);
            var g = svg.append("g").html('<path fill="#444444" d="M10.797 2.656c-0.263-0.358-0.629-0.777-1.030-1.179s-0.82-0.768-1.179-1.030c-0.61-0.447-0.905-0.499-1.075-0.499h-5.863c-0.521 0-0.946 0.424-0.946 0.946v10.213c0 0.521 0.424 0.946 0.946 0.946h8.7c0.521 0 0.946-0.424 0.946-0.946v-7.376c0-0.169-0.052-0.465-0.499-1.075zM9.231 2.012c0.363 0.363 0.648 0.69 0.858 0.962h-1.82v-1.82c0.272 0.21 0.599 0.495 0.962 0.858zM10.539 11.106c0 0.102-0.087 0.189-0.189 0.189h-8.7c-0.102 0-0.189-0.087-0.189-0.189v-10.213c0-0.102 0.087-0.189 0.189-0.189 0 0 5.862-0 5.863 0v2.648c0 0.209 0.169 0.378 0.378 0.378h2.648v7.376z"></path><path fill="#444444" d="M8.648 9.783h-5.296c-0.209 0-0.378-0.169-0.378-0.378s0.169-0.378 0.378-0.378h5.296c0.209 0 0.378 0.169 0.378 0.378s-0.169 0.378-0.378 0.378z"></path>            <path fill="#444444" d="M8.648 8.27h-5.296c-0.209 0-0.378-0.169-0.378-0.378s0.169-0.378 0.378-0.378h5.296c0.209 0 0.378 0.169 0.378 0.378s-0.169 0.378-0.378 0.378z"></path>            <path fill="#444444" d="M8.648 6.756h-5.296c-0.209 0-0.378-0.169-0.378-0.378s0.169-0.378 0.378-0.378h5.296c0.209 0 0.378 0.169 0.378 0.378s-0.169 0.378-0.378 0.378z"></path>');


            for(i=0; i<altsL; i++) {
                tip += i!==0?'<br/>':'' + '<b>Mutation Effect: '+_alterations[i].knownEffect + '</b><br/>' + _alterations[i].description + '<br/>';
            }
            if (genomicEventObs.mutations.getValue(hashId, 'oncokb').oncogenic){
                tip += '<br/><span style="float:right"><i>Powered by OncoKB(Beta)</i></span><br/><br/><i>OncoKB is under development, please pardon errors and omissions. Please send feedback to <a href="mailto:oncokb@cbio.mskcc.org" title="Contact us">oncokb@cbio.mskcc.org</a></i>';
            }

            if(tip !== '') {
                $(g).css('display', '');
                $(g).qtip('destroy', true);
                $(g).qtip({
                    content: {text: tip},
                    hide: { fixed: true, delay: 100 },
                    style: { classes: 'qtip-light qtip-rounded qtip-shadow', tip: true },
                    position: {my:'center right',at:'center left',viewport: $(window)}
                });
            }
        }
    }

    function createOncoKBColumnCell(target, prevalence, progImp, treatments, trials) {
        var svg = d3.select($(target)[0])
                .append("svg")
                .attr("width", 20)
                .attr("height", 20);
        var qtipContext = '', i;

        if (treatments.length > 0) {
            var g = svg.append("g")
                    .attr("transform", "translate(0, 6)");
            var level = getHighestLevel($(target).attr('hashId'));
            var isResistance = /R/g.test(level);
            var numberLevel = level.match(/\d+/)[0];
            var treatmentDataTable;

            oncokbIcon(g,'Tx',"#5555CC", 9);
            oncokbLevelIcon(g, numberLevel, isResistance?'#ff0000':'#008000');

            qtipContext = createTreatmentsStr(treatments);

            $(g).qtip('destroy', true);
            $(g).qtip({
                content: {text: qtipContext},
                hide: { fixed: true, delay: 100, event: "mouseleave"},
                style: { classes: 'qtip-light qtip-rounded qtip-shadow oncokb-qtip', tip: true },
                show: {event: "mouseover", solo: true, delay: 0},
                position: {my:'center right',at:'center left',viewport: $(window)},
                events: {
                    render: function (event, api) {
                        $(this).find('.oncokb-description-more').click(function(){
                            $(this).parent().parent().find('.oncokb-fullDescription').css('display', 'block');
                            $(this).parent().parent().find('.oncokb-shortDescription').css('display', 'none');
                            if(treatmentDataTable){
                                treatmentDataTable.fnAdjustColumnSizing();
                            }
                        });
                        treatmentDataTable = $(this).find('.oncokb-treatments-datatable').dataTable({
                            "columnDefs": [
                                {
                                    "orderDataType": "oncokb-level",
                                    "targets": 1
                                },
                                {
                                    "orderData": [1, 0],
                                    "targets": 1
                                }
                            ]
                            "sDom": 'rt',
                            "bPaginate": false,
                            "bScrollCollapse": true,
                            "sScrollY": 400,
                            "autoWidth": true,
                            "order": [[ 1, "asc" ]]
                        });
                    },
                    visible: function(event, api) {
                        if(treatmentDataTable){
                            treatmentDataTable.fnAdjustColumnSizing();
                        }
                    }
                }
            });
        }

        if (progImp.length > 0) {
            var g = svg.append("g")
                    .attr("transform", "translate(20, 6)");
            var progImpDataTable;
            oncokbIcon(g,'Px',"#5555CC", 9);

            qtipContext = oncokbGetString(progImp, 'PROGNOSTIC IMPLICATIONS', 'progImp');

            $(g).qtip('destroy', true);
            $(g).qtip({
                content: {text: qtipContext},
                hide: { fixed: true, delay: 100 },
                style: { classes: 'qtip-light qtip-rounded qtip-shadow oncokb-qtip', tip: true },
                position: {my:'center right',at:'center left',viewport: $(window)},
                events: {
                    render: function() {
                        $(this).find('.oncokb-description-more').click(function(){
                            $(this).parent().parent().find('.oncokb-fullDescription').css('display', 'block');
                            $(this).parent().parent().find('.oncokb-shortDescription').css('display', 'none');
                            if(progImpDataTable){
                                progImpDataTable.fnAdjustColumnSizing();
                            }
                        });
                        progImpDataTable = $(this).find('.oncokb-progImp-datatable').dataTable({
                            "sDom": 'rt',
                            "bPaginate": false,
                            "bScrollCollapse": true,
                            "sScrollY": 400,
                            "autoWidth": true,
                            "order": [[ 0, "asc" ]]
                        });
                    },
                    visible: function(event, api) {
                        if(progImpDataTable){
                            progImpDataTable.fnAdjustColumnSizing();
                        }
                    }
                }
            });
        }

        if (trials.length > 0) {
            var g = svg.append("g")
                    .attr("transform", "translate(40, 6)");
            var trialsL = trials.length;
            var trialDataTable;

            oncokbIcon(g,'CT',"#5555CC", 9);

            qtipContext = '<table class="oncokb-trials-datatable"><thead><tr><th style="white-space:nowrap">TUMOR TYPE</th><th>TRIALS</th></tr></thead><tbody>';
            for(i = 0; i < trialsL; i++){
                qtipContext += '<tr>';
                qtipContext += '<td style="white-space:nowrap">' + trials[i].tumorType + '</td>';
                qtipContext += '<td>' + getTrialsStr(trials[i].list) + '</td>';
                qtipContext +='</tr>';
            }

            $(g).qtip('destroy', true);
            $(g).qtip({
                content: {text: qtipContext},
                hide: { fixed: true, delay: 100 },
                style: { classes: 'qtip-light qtip-rounded qtip-shadow oncokb-qtip-sm', tip: true },
                position: {my:'center right',at:'center left',viewport: $(window)},
                events: {
                    render: function (event, api) {
                        trialDataTable = $(this).find('.oncokb-trials-datatable').dataTable({
                            "sDom": 'rt',
                            "bPaginate": false,
                            "bScrollCollapse": true,
                            "sScrollY": 400,
                            "autoWidth": true,
                            "order": [[ 0, "asc" ]]
                        });
                    },
                    visible: function(event, api) {
                        if(trialDataTable){
                            trialDataTable.fnAdjustColumnSizing();
                        }
                    }
                }
            });
        }

        if (prevalence.length > 0) {
            var g = svg.append("g")
                    .attr("transform", "translate(60, 6)");
            var prevalenceDataTable;
            oncokbIcon(g,'Pr',"#5555CC", 9);

            qtipContext = oncokbGetString(prevalence, 'PREVALENCE', 'prevalence');

            $(g).qtip('destroy', true);
            $(g).qtip({
                content: {text: qtipContext},
                hide: { fixed: true, delay: 100 },
                style: { classes: 'qtip-light qtip-rounded qtip-shadow oncokb-qtip', tip: true },
                position: {my:'center right',at:'center left',viewport: $(window)},
                events: {
                    render: function() {
                        $(this).find('.oncokb-description-more').click(function(){
                            $(this).parent().parent().find('.oncokb-fullDescription').css('display', 'block');
                            $(this).parent().parent().find('.oncokb-shortDescription').css('display', 'none');
                            if(prevalenceDataTable){
                                prevalenceDataTable.fnAdjustColumnSizing();
                            }
                        });
                        prevalenceDataTable = $(this).find('.oncokb-prevalence-datatable').dataTable({
                            "sDom": 'rt',
                            "bPaginate": false,
                            "bScrollCollapse": true,
                            "sScrollY": 400,
                            "autoWidth": true,
                            "order": [[ 0, "asc" ]]
                        });
                    },
                    visible: function(event, api) {
                        if(prevalenceDataTable){
                            prevalenceDataTable.fnAdjustColumnSizing();
                        }
                    }
                }
            });
        }
    }

    function getTrialsStr(trials) {
        var i, str = '';

        if(trials instanceof Array){
            var trialsL = trials.length;
            for(i = 0; i < trialsL; i++){
                str += OncoKBConnector.findRegex(trials[i].nctId);
                if(i != trialsL - 1) {
                    str += ' ';
                }
            }
        }
        return str;
    }

    function getHighestLevel(hashId) {
        var level = '';
        var treatments = genomicEventObs.mutations.getValue(hashId, 'oncokb').treatments;
        var treatmentsL = treatments.length;
        var levels = ['4', '3', '2B','2A', '1', '0', 'R3', 'R2', 'R1'];
        var highestLevelIndex = -1;
        for(var i = 0; i < treatmentsL; i++){
            var _level = treatments[i].level.match(/LEVEL_(R?\d[AB]?)/);
            if(_level instanceof Array && _level.length >= 2){
                var _index = levels.indexOf(_level[1]);
                if(_index > highestLevelIndex){
                    highestLevelIndex = _index;
                }
            }
        }
        return levels[highestLevelIndex];
    }

    function listenToBamIgvClick(elem) {
        $(elem).each(function(){
                // TODO use mutation id, instead of binding url to attr alt
                var url = $(this).attr("alt");

                $(this).click(function(evt) {
                        // get parameters from the server and call related igv function
                        $.getJSON(url, function(data) {
                                //console.log(data);
                                // TODO this call displays warning message (resend)
                                prepIGVLaunch(data.bamFileUrl, data.encodedLocus, data.referenceGenome, data.trackName);
                        });
                });
        });
    }

    function plotMutRate(div,mutations) {
        $(div).each(function() {
            if (!$(this).is(":empty")) return;
            var gene = $(this).attr("alt");
            var keymutrate = mutations.getValue(gene, 'keymutrate');
            var keyperc = 100 * keymutrate / numPatientInSameMutationProfile;
            var genemutrate = mutations.getValue(gene, 'genemutrate');
            var geneperc = 100 * genemutrate / numPatientInSameMutationProfile;
            
            var data = [keyperc, geneperc-keyperc, 100-geneperc];
            var colors = ["green", "lightgreen", "#ccc"];
                        
            var svg = d3.select($(this)[0])
                .append("svg")
                .attr("width", 86)
                .attr("height", 12);
        
            var percg = svg.append("g");
            percg.append("text")
                    .attr('x',70)
                    .attr('y',11)
                    .attr("text-anchor", "end")
                    .attr('font-size',10)
                    .text(geneperc.toFixed(1)+"%");
            
            var gSvg = percg.append("g");
            var pie = d3AccBar(gSvg, data, 30, colors);
            var tip = ""+genemutrate+" sample"+(genemutrate===1?"":"s")
                + " (<b>"+geneperc.toFixed(1) + "%</b>)"+" in this study "+(genemutrate===1?"has":"have")+" mutated "
                + mutations.getValue(gene, "gene")
                + ", out of which "+keymutrate
                + " (<b>"+keyperc.toFixed(1) + "%</b>) "
                + (keymutrate===1?"has ":"have ")+mutations.getValue(gene,'key')+" mutations.";
            qtip($(percg), tip);
            
            // mutsig
            var mutsig = mutations.getValue(gene, 'mutsig');
            if (mutsig) {
                tip = "<b>MutSig</b><br/>Q-value: "+mutsig.toPrecision(2);
                var circle = svg.append("g")
                    .attr("transform", "translate(80,6)");
                d3CircledChar(circle,"M","#55C","#66C");
                qtip($(circle), tip);
            }
            
        });
        
        function qtip(el, tip) {
            $(el).qtip({
                content: {text: tip},
	            show: {event: "mouseover"},
                hide: {fixed: true, delay: 200, event: "mouseout"},
                style: { classes: 'qtip-light qtip-rounded' },
                position: {my:'top right',at:'bottom center',viewport: $(window)}
            });
        }
    }

    function addCosmicTooltip(table_id) {
        $("."+table_id+"-cosmic-tip").qtip({
            content: {
                attr: 'alt'
            },
            events: {
                render: function(event, api) {
                    $("."+table_id+"-cosmic-table.uninitialized").dataTable( {
                        "sDom": 'pt',
                        "bJQueryUI": true,
                        "bDestroy": true,
                        "aoColumnDefs": [
                            {
                                "aTargets": [ 0 ],
                                "mDataProp": function(source,type,value) {
                                    if (type==='set') {
                                        source[0]=value;
                                    } else if (type==='display') {
                                        return '<a href="http://cancer.sanger.ac.uk/cosmic/mutation/overview?id='+source[0]+'">'+source[0]+'</a>';
                                    } else {
                                        return source[0];
                                    }
                                }
                            },
                            {
                                "aTargets": [ 1 ],
                                "mDataProp": function(source,type,value) {
                                    if (type==='set') {
                                        source[1]=value;
                                    } else if (type==='sort') {
                                        return parseInt(source[1].replace( /^\D+/g, ''));
                                    } else if (type==='type') {
                                        return 0;
                                    } else {
                                        return source[1];
                                    }
                                }
                            }
                        ],
                        "oLanguage": {
                            "sInfo": "&nbsp;&nbsp;(_START_ to _END_ of _TOTAL_)&nbsp;&nbsp;",
                            "sInfoFiltered": "",
                            "sLengthMenu": "Show _MENU_ per page"
                        },
                        "aaSorting": [[2,'desc']],
                        "iDisplayLength": 10
                    } ).removeClass('uninitialized');
                }
            },
	        show: {event: "mouseover"},
            hide: {fixed: true, delay: 100, event: "mouseout"},
            style: { classes: 'qtip-light qtip-rounded qtip-wide' },
            position: {my:'top right',at:'bottom center',viewport: $(window)}
        });
    }
    
    var numPatientInSameMutationProfile = <%=numPatientInSameMutationProfile%>;
    
    $(document).ready(function(){
        $('#mutation_id_filter_msg').hide();
        var params = {
            <%=PatientView.SAMPLE_ID%>:caseIdsStr,
            <%=PatientView.MUTATION_PROFILE%>:mutationProfileId
        };

        if (cnaProfileId) {
            params['<%=PatientView.CNA_PROFILE%>'] = cnaProfileId;
        }
        
        if (mrnaProfileId) {
            params['<%=PatientView.MRNA_PROFILE%>'] = mrnaProfileId;
        }
        
        if (drugType) {
            params['<%=PatientView.DRUG_TYPE%>'] = drugType;
        }

        accessOncoKB(function(){
            $.post("mutations.json",
                    params,
                    function(data) {
                        determineOverviewMutations(data);
                        genomicEventObs.mutations.setData(data);
                        genomicEventObs.fire('mutations-built');

                        // summary table
                        buildMutationsDataTable(genomicEventObs.mutations,genomicEventObs.mutations.getEventIds(true), 'mutation_summary_table',
                                '<"H"<"mutation-summary-table-name">fr>t<"F"<"mutation-show-more"><"datatable-paging"pl>>', 25, "No mutation events of interest", true);
                        var numFiltered = genomicEventObs.mutations.getNumEvents(true);
                        var numAll = genomicEventObs.mutations.getNumEvents(false);
                        $('.mutation-show-more').html("<a href='#mutations' onclick='switchToTab(\"tab_mutations\");return false;'\n\
                      title='Show more mutations of this patient'>Show all "
                        +numAll+" mutations</a>");
                        $('.mutation-show-more').addClass('datatable-show-more');
                        var mutationSummary;
                        if (numAll===numFiltered) {
                            mutationSummary = ""+numAll+" mutations";
                        } else {
                            mutationSummary = "Mutations of interest"
                            +(numAll==0?"":(" ("
                            +numFiltered
                            +" of <a href='#mutations' onclick='switchToTab(\"tab_mutations\");return false;'\n\
                         title='Show more mutations of this patient'>"
                            +numAll
                            +"</a>)"))
                            +" <img id='mutations-summary-help' src='images/help.png' \n\
                        title='This table contains somatic mutations in genes that are \n\
                        <ul><li>either annotated cancer genes</li>\n\
                        <li>or recurrently mutated, namely\n\
                            <ul><li>MutSig Q < 0.05, if MutSig results are available</li>\n\
                            <li>otherwise, mutated in > 5% of samples in the study with &ge; 50 samples</li></ul> </li>\n\
                        <li>or with > 5 overlapping entries in COSMIC.</li></ul>'/>";
                        }
                        $('.mutation-summary-table-name').html(mutationSummary);
                        $('#mutations-summary-help').qtip({
                            content: { attr: 'title' },
                            style: { classes: 'qtip-light qtip-rounded' },
                            position: { my:'top center',at:'bottom center',viewport: $(window) }
                        });
                        $('.mutation-summary-table-name').addClass("datatable-name");
                        $('#mutation_summary_wrapper_table').show();
                        $('#mutation_summary_wait').remove();

                        // mutations
                        buildMutationsDataTable(genomicEventObs.mutations,genomicEventObs.mutations.getEventIds(false),
                                'mutation_table', '<"H"<"all-mutation-table-name">fr>t<"F"C<"datatable-paging"pil>>', 100, "No mutation events", false);
                        $('.all-mutation-table-name').html(
                                ""+genomicEventObs.mutations.getNumEvents()+" nonsynonymous mutations");
                        $('.all-mutation-table-name').addClass("datatable-name");
                        $('#mutation_wrapper_table').show();
                        $('#mutation_wait').remove();

                        var pancanMutationsUrl = "pancancerMutations.json";
                        var byKeywordResponse = [];
                        var byHugoResponse = [];

                        function munge(response, key) {
                            // munge data to get it into the format: keyword -> corresponding datum
                            return d3.nest().key(function(d) { return d[key]; }).entries(response)
                                    .reduce(function(acc, next) { acc[next.key] = next.values; return acc;}, {});
                        }

                        var splitJobs = function(cmd, reqData, type) {
                            var jobs = [];
                            var batchSize = 1000;

                            var numOfBatches = Math.ceil(reqData.length / batchSize);
                            for(var b=0; b<numOfBatches; b++) {
                                var first = b*batchSize;
                                var last = Math.min((b+1)*batchSize, reqData.length);

                                var accData = reqData.slice(first, last).join(",");

                                jobs.push(
                                        $.post(pancanMutationsUrl,
                                                {
                                                    cmd: cmd,
                                                    q: accData
                                                }, function(batchData) {
                                                    if(cmd == "byKeywords") {
                                                        byKeywordResponse = byKeywordResponse.concat(batchData);
                                                    } else if( cmd == "byHugos") {
                                                        byHugoResponse = byHugoResponse.concat(batchData);
                                                    } else {
                                                        console.trace("Ooops! Something is wrong!");
                                                    }
                                                }
                                        )
                                );

                            }

                            return jobs;
                        };

                        var jobs = splitJobs("byKeywords", genomicEventObs.mutations.data.key)
                                .concat(splitJobs("byHugos", genomicEventObs.mutations.data.gene));
                        $.when.apply($, jobs).done(function() {
                            genomicEventObs.pancan_mutation_frequencies.setData(
                                    _.extend(munge(byKeywordResponse, "keyword"), munge(byHugoResponse, "hugo")));
                            genomicEventObs.fire("pancan-mutation-frequency-built");
                        });

                    }
                    ,"json"
            );
        });
    });
    
    var patient_view_mutsig_qvalue_threhold = 0.05;
    var patient_view_genemutrate_threhold = 0.05;
    var patient_view_genemutrate_apply_cohort_count = 50;
    var patient_view_cosmic_threhold = 5;
    function determineOverviewMutations(data) {
        var overview = [];
        var len = data['id'].length;
        var cancerGene = data['cancer-gene'];
        var mutsig = data['mutsig'];
        var mutrate = data['genemutrate'];
        var cosmic = data['cosmic'];
        
        var noMutsig = true;
        for (var i=0; i<len; i++) {
            if (mutsig[i]) {
                noMutsig = false;
                break;
            }
        }
        
        for (var i=0; i<len; i++) {
            if (cancerGene[i]) {
                overview.push(true);
                continue;
            }
            
            if (noMutsig) {
                if (numPatientInSameMutationProfile>=patient_view_genemutrate_apply_cohort_count
                  && mutrate[i]/numPatientInSameMutationProfile>=patient_view_genemutrate_threhold) {
                    overview.push(true);
                    continue;
                }
            } else {
                if (mutsig[i]&&mutsig[i]<=patient_view_mutsig_qvalue_threhold) {
                    overview.push(true);
                    continue;
                }
            }
            
            var ncosmic = 0;
            var cosmicI= cosmic[i];
            if (cosmicI) {
                var lenI = cosmicI.length;
                for(var j=0; j<lenI && ncosmic<patient_view_cosmic_threhold; j++) {
                    ncosmic += cosmicI[j][2];
                }
                if (ncosmic>=patient_view_cosmic_threhold) {
                    overview.push(true);
                    continue;
                }
            }
            
            overview.push(false);
        }
        data['overview'] = overview;
    }
    
    function getMutGeneAA(mutIds) {
        var m = [];
        for (var i=0; i<mutIds.length; i++) {
            var gene = genomicEventObs.mutations.getValue(mutIds[i],'gene');
            var aa = genomicEventObs.mutations.getValue(mutIds[i],'aa');
            m.push(gene+': '+aa);
        }
        return m;
    }
    
    function filterMutationsTableByIds(mutIdsRegEx) {
        var mut_table = $('#mutation_table').dataTable();
        var n = mut_table.fnSettings().fnRecordsDisplay();
        mut_table.fnFilter(mutIdsRegEx, mutTableIndices["id"],true);
        if (n!=mut_table.fnSettings().fnRecordsDisplay())
            $('#mutation_id_filter_msg').show();
    }
    
    function unfilterMutationsTableByIds() {
        var mut_table = $('#mutation_table').dataTable();
        mut_table.fnFilter("", mutTableIndices["id"]);
        $('#mutation_id_filter_msg').hide();
    }

    // TODO: DUPLICATED FUNCTION from mutation-mapper.
    // we should use mutation mapper as a library in patient view...
    /**
     * Checks if given 2 protein changes are completely different from each other.
     *
     * @param proteinChange
     * @param aminoAcidChange
     * @returns {boolean}
     */
    function isDifferentProteinChange(proteinChange, aminoAcidChange)
    {
	    var different = false;

	    proteinChange = normalizeProteinChange(proteinChange);
	    aminoAcidChange = normalizeProteinChange(aminoAcidChange);

	    // if the normalized strings are exact, no need to do anything further
	    if (aminoAcidChange !== proteinChange)
	    {
		    // assuming each uppercase letter represents a single protein
		    var proteinMatch1 = proteinChange.match(/[A-Z]/g);
		    var proteinMatch2 = aminoAcidChange.match(/[A-Z]/g);

		    // assuming the first numeric value is the location
		    var locationMatch1 = proteinChange.match(/[0-9]+/);
		    var locationMatch2 = aminoAcidChange.match(/[0-9]+/);

		    // assuming first lowercase value is somehow related to
		    var typeMatch1 = proteinChange.match(/([a-z]+)/);
		    var typeMatch2 = aminoAcidChange.match(/([a-z]+)/);

		    if (locationMatch1 && locationMatch2 &&
		        locationMatch1.length > 0 && locationMatch2.length > 0 &&
		        locationMatch1[0] != locationMatch2[0])
		    {
			    different = true;
		    }
		    else if (proteinMatch1 && proteinMatch2 &&
		             proteinMatch1.length > 0 && proteinMatch2.length > 0 &&
		             proteinMatch1[0] !== "X" && proteinMatch2[0] !== "X" &&
		             proteinMatch1[0] !== proteinMatch2[0])
		    {
			    different = true;
		    }
		    else if (proteinMatch1 && proteinMatch2 &&
		             proteinMatch1.length > 1 && proteinMatch2.length > 1 &&
		             proteinMatch1[1] !== proteinMatch2[1])
		    {
			    different = true;
		    }
		    else if (typeMatch1 && typeMatch2 &&
		             typeMatch1.length > 0 && typeMatch2.length > 0 &&
		             typeMatch1[0] !== typeMatch2[0])
		    {
			    different = true;
		    }
	    }

	    return different;
    }

    // TODO: DUPLICATED FUNCTION from mutation-mapper.
    function normalizeProteinChange(proteinChange)
    {
            if (cbio.util.checkNullOrUndefined(proteinChange)) {
                return "";
            }
        
	    var prefix = "p.";

	    if (proteinChange.indexOf(prefix) !== -1)
	    {
		    proteinChange = proteinChange.substr(proteinChange.indexOf(prefix) + prefix.length);
	    }

	    return proteinChange;
    }

</script>

<div id="mutation_wait"><img src="images/ajax-loader.gif"/></div>
<div id="mutation_id_filter_msg"><font color="red">The following table contains filtered mutations.</font>
<button onclick="unfilterMutationsTableByIds(); return false;" style="font-size: 1em;">Show all mutations</button></div>
<div  id="pancan_mutations_histogram_container"></div>
<table cellpadding="0" cellspacing="0" border="0" id="mutation_wrapper_table" width="100%" style="display:none;">
    <tr>
        <td>
            <table cellpadding="0" cellspacing="0" border="0" class="display" id="mutation_table">
                <%@ include file="mutations_table_template.jsp"%>
            </table>
        </td>
    </tr>
</table>