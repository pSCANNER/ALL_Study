Use Altamed_OMOP5_PCONET4
go

/*========================================================================================

-- Query Name: pSCANNER Acute Lymphoblastic Leukemia
-- Requestor: Victoria Ngo, Kathy Kim (UC Davis)
-- Author: Paulina Paul
-- Create Date: 05/11/2018
-- Code Files used: pSCANNER_Attachment_Data_Request_2018.05.04 (Appendix A, B, C, D and E)


-- Code Tables: 
		Appendix A => Data_Concierge_Staging_PP.appendix_A 
		Appendix B => Data_Concierge_Staging_PP.appendix_B
		Appendix C => Data_Concierge_Staging_PP.appendix_C 
		Appendix D => Data_Concierge_Staging_PP.appendix_D 
		Appendix E => Data_Concierge_Staging_PP.appendix_E
		
		
--Steps:
	1) Import the appendix A-E to SQL table(s)		
	2) Run the following query
	3) This code returns a 5-digit zip code. Please check if 5-digit zip code can be  
		returned for a de-identified data request.
	4) Mask the ID fields (person ID, visit ID etc)
========================================================================================*/



--concept_ids with ALL diagnosis (Appendix A)
if OBJECT_ID ('tempdb.dbo.#ALL_concept_id') is not null drop table #ALL_concept_id
select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
into #ALL_concept_id 
from vocab.CONCEPT c
join Data_Concierge_Staging_PP.appendix_A aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-10'
where c.VOCABULARY_ID in ('ICD10','ICD10CM')
union 
select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
from vocab.CONCEPT c
join Data_Concierge_Staging_PP.appendix_A aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-9'
where c.VOCABULARY_ID in ('ICD9CM')


select * from #ALL_concept_id



--(I) Data Request (ADD age >=18)
	--patients with ALL diagnosis and condition start date
	if OBJECT_ID('tempdb.dbo.#ALL_patients') Is not null drop table #ALL_patients
	select co.person_id, co.visit_occurrence_id, co.condition_start_date, co.condition_end_date, co.condition_source_value
	-- , all_dx.CONCEPT_CODE
	into #ALL_patients 
	from omop5.condition_occurrence co
	join #ALL_concept_id all_dx on all_dx.CONCEPT_ID = co.condition_source_concept_id 
	join omop5.person p on co.person_id = p.person_id 
	where datediff( dd, 
		cast(		
			concat(p.year_of_birth, '-', 
			right('0' + cast(p.month_of_birth as varchar), 2), '-', 
			right('0' + cast(p.day_of_birth as varchar), 2) 
			) AS datetime),
		getdate())/365.0 >= 18.0
	group by co.person_id, visit_occurrence_id, condition_start_date, condition_end_date, condition_source_value , all_dx.CONCEPT_CODE

	select * from #ALL_patients


	--Relapse date for ALL Patients (Currenly pulling all records with any of the 'relapse' codes)
	if OBJECT_ID('tempdb.dbo.#ALL_Relapse') Is not null drop table #ALL_Relapse
	select co.person_id, co.condition_start_date as relapse_date, all_relapse.concept_code, all_relapse.code_description
	into #ALL_Relapse
	from #ALL_patients allp
	join  omop5.condition_occurrence co on co.person_id = allp.person_id 
	join #ALL_concept_ID  all_relapse on all_relapse.concept_id = co.condition_source_concept_id and all_relapse.code_description like '%relapse%'
	group by co.person_id, co.condition_start_date , all_relapse.concept_code, all_relapse.code_description

	select * from #ALL_Relapse



	--Co-morbidities at the time of diagnosis
	if OBJECT_ID('tempdb.dbo.#ALL_CoMorbities') Is not null drop table #ALL_CoMorbities
	select co.*
	into #ALL_CoMorbities
	from #ALL_patients allp
	join omop5.condition_occurrence co on co.person_id = allp.person_id 

	select * from #ALL_CoMorbities



	--previous cancer diagnosis	
		--concept IDs from Appendix C
		if object_id ('tempdb.dbo.#all_cancer_concept_id') is not null drop table #all_cancer_concept_id
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		into #all_cancer_concept_id 
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_C aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-10'
		where c.VOCABULARY_ID in ('ICD10','ICD10CM')
		union 
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_C aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-9'
		where c.VOCABULARY_ID in ('ICD9CM')		
		
	--Cancer diagnosis	
	if OBJECT_ID('tempdb.dbo.#ALL_cancer_dx') Is not null drop table #ALL_cancer_dx
	select co.person_id, co.visit_occurrence_id, co.condition_start_date, co.condition_end_date, co.condition_source_value
	-- , all_dx.CONCEPT_CODE
	into #ALL_cancer_dx 
	from omop5.condition_occurrence co
	join #ALL_patients allp on allp.person_id = co.person_id 
	join #all_cancer_concept_id all_dx on all_dx.CONCEPT_ID = co.condition_source_concept_id 
	group by co.person_id, co.visit_occurrence_id, co.condition_start_date, co.condition_end_date, co.condition_source_value , all_dx.CONCEPT_CODE
		
	select * from #ALL_cancer_dx			




	--death date
	select co.person_id, co.death_date 
	from omop5.death co
	join #ALL_patients allp on allp.person_id = co.person_id 
	GROUP by  co.person_id, co.death_date




	--Complications with ALL (Appendix D)
		--concept IDs from Appendix D
		if object_id ('tempdb.dbo.#all_complication_concept_id') is not null drop table #all_complication_concept_id
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		into #all_complication_concept_id 
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_D aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-10'
		where c.VOCABULARY_ID in ('ICD10','ICD10CM')
		union 
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_D aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'ICD-9'
		where c.VOCABULARY_ID in ('ICD9CM')		
		
	-- Complications with ALL	
	if OBJECT_ID('tempdb.dbo.#ALL_complications') Is not null drop table #ALL_complications
	select co.person_id, co.visit_occurrence_id, co.condition_start_date, co.condition_end_date, co.condition_source_value
	-- , all_dx.CONCEPT_CODE
	into #ALL_complications
	from omop5.condition_occurrence co
	join #ALL_patients allp on allp.person_id = co.person_id 
	join #all_complication_concept_id all_dx on all_dx.CONCEPT_ID = co.condition_source_concept_id 
	group by co.person_id, co.visit_occurrence_id, co.condition_start_date, co.condition_end_date, co.condition_source_value , all_dx.CONCEPT_CODE
		
	select * from #ALL_complications			

	



--(II) Data Location
	--(5) Demographics (zip code not included; included payer_source_value and plan_source_value)
	if OBJECT_ID('tempdb.dbo.#ALL_Demographics') Is not null drop table #ALL_Demographics
	select co.person_id, gender_concept_id, year_of_birth, race_concept_id, ethnicity_concept_id, 
	l.zip, pp.payer_plan_period_id, payer_source_value, plan_source_value
	into #ALL_Demographics
	from #ALL_patients allp
	join omop5.person co on co.person_id = allp.person_id 
	left join omop5.payer_plan_period pp on pp.person_id = allp.person_id 
	LEFT join omop5.location l on l.location_id = co.location_id 
	group by co.person_id, gender_concept_id, year_of_birth, race_concept_id, ethnicity_concept_id, 
	l.zip, pp.payer_plan_period_id, payer_source_value, plan_source_value
	
	select * from #ALL_Demographics
	
	----5 digit zip code (from clarity if its not avaiable in OMOP)
	--if OBJECT_ID('tempdb.dbo.#zip') Is not null drop table #zip
	--select distinct  pla.pat_id, l.*, pla.person_id  
	--into #zip
	--from openquery([hs-eclarity-v],
	--	'select pat_id, zip from patient') l 
	--join link5.pat_link_all pla on l.pat_id = pla.pat_id 
	--join #ALL_patients allp on allp.person_id = pla.person_id 
	
	
	
	
	
	--(6) All visits (Encounters: IP, OP and ER)
	Declare @Care_Site varchar(20) = 'UCSD'
	
	if OBJECT_ID('tempdb.dbo.#ALL_visits') Is not null drop table #ALL_visits
	select co.person_id, co.visit_occurrence_id, co.visit_concept_id, co.visit_source_value, visit_source_concept_id, 
		visit_start_datetime, visit_end_datetime, @Care_Site as care_site_id, 
		admitting_concept_id, admitting_source_value, discharge_to_concept_id, discharge_to_source_value
	into #ALL_visits
	from #ALL_patients allp	
	join omop5.visit_occurrence co on co.visit_occurrence_id = allp.visit_occurrence_id 
	--join omop5.visit_occurrence co on co.person_id = allp.person_id 
	where co.visit_concept_id in (
			select concept_id from vocab.concept where domain_id = 'visit'
			and concept_code in ('IP','OP','ER','ERIP')
		)			
	group by co.person_id, co.visit_occurrence_id, co.visit_concept_id, co.visit_source_value, visit_source_concept_id, 
		visit_start_datetime, visit_end_datetime,
		admitting_concept_id, admitting_source_value, discharge_to_concept_id, discharge_to_source_value	 

	select * from #ALL_visits

	
	
	
	--Discharge Medications: (All medications associated w/ the visits)
	if OBJECT_ID('tempdb.dbo.#ALL_meds') Is not null drop table #ALL_meds
	select de.drug_exposure_id, de.person_id, de.drug_concept_id, de.drug_exposure_start_date, de.drug_exposure_end_date,
	de.drug_type_concept_id, de.stop_reason, de.refills, de.quantity, de.days_supply, de.sig, de.route_concept_id, 
	de.lot_number, de.visit_occurrence_id, de.drug_source_value, 
	de.drug_source_concept_id, de.route_source_value--, de.drug_unit_source_value
	into #ALL_meds 
	from #ALL_visits vo
	join omop5.drug_exposure de on de.visit_occurrence_id = vo.visit_occurrence_id
	group by de.drug_exposure_id, de.person_id, de.drug_concept_id, de.drug_exposure_start_date, de.drug_exposure_end_date,
	de.drug_type_concept_id, de.stop_reason, de.refills, de.quantity, de.days_supply, de.sig, de.route_concept_id, 
	de.lot_number, de.visit_occurrence_id, de.drug_source_value, 
	de.drug_source_concept_id, de.route_source_value
	
	
	
	
	
	--(7) Lab values at Diagnosis
		--Lab codes 
		if object_id ('tempdb.dbo.#lab_codes') is not null drop table #lab_codes
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		into #lab_codes 
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_E aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'LOINC'
		where c.VOCABULARY_ID in ('LOINC')
		union 
		select CONCEPT_ID, CONCEPT_CODE, VOCABULARY_ID, INVALID_REASON, aa.code_description
		from vocab.CONCEPT c
		join Data_Concierge_Staging_PP.appendix_E aa on aa.code  = c.CONCEPT_CODE and aa.code_type = 'CPT'
		where c.VOCABULARY_ID in ('CPT')		
	
	
	if OBJECT_ID('tempdb.dbo.#ALL_Labs') Is not null drop table #ALL_Labs
	select de.measurement_id, de.person_id, de.measurement_concept_id, de.measurement_date, de.measurement_type_concept_id,
	de.value_as_number, de.value_as_concept_id, de.unit_concept_id, de.range_low, de.range_high, de.visit_occurrence_id,
	de.measurement_source_value, de.measurement_source_concept_id, de.unit_source_value, de.value_source_value
	into #ALL_Labs
	from #ALL_patients vo
	join omop5.measurement de on de.visit_occurrence_id = vo.visit_occurrence_id
	join #lab_codes lc on lc.concept_id = de.measurement_source_concept_id 
	group by  de.measurement_id, de.person_id, de.measurement_concept_id, de.measurement_date, de.measurement_type_concept_id,
	de.value_as_number, de.value_as_concept_id, de.unit_concept_id, de.range_low, de.range_high, de.visit_occurrence_id,
	de.measurement_source_value, de.measurement_source_concept_id, de.unit_source_value, de.value_source_value
	
	select * from #all_labs
	


	
	--(8) Treatments 
	if OBJECT_ID('tempdb.dbo.#treatments') Is not null drop table #treatments	
	select c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, a.code_description
	into #treatments
	from Data_Concierge_Staging_PP.appendix_B a
	join vocab.concept c on a.code = c.concept_code and c.vocabulary_id = 'DRG'
	where code_type = 'MS-DRG v35'
	union 
	select  c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, a.code_description
	from Data_Concierge_Staging_PP.appendix_B a
	join vocab.concept c on a.code = c.concept_code and c.vocabulary_id = 'ICD10CM'
	 where code_type = 'ICD-10cm'
	union 
	select c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, a.code_description
	from Data_Concierge_Staging_PP.appendix_B a
	join vocab.concept c on a.code = c.concept_code and c.vocabulary_id = 'CPT4'
	where code_type = 'CPT4'
	union 
	select  c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, a.code_description
	from Data_Concierge_Staging_PP.appendix_B a
	join vocab.concept c on a.code = c.concept_code and c.vocabulary_id = 'HCPCS'
	where code_type = 'HCPC'
	union 
	select  c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, a.code_description
	from Data_Concierge_Staging_PP.appendix_B a
	join vocab.concept c on a.code = c.concept_code and c.vocabulary_id in ('ICD9CM', 'ICD9Proc')
	where code_type = 'ICD-9cm'
	union 
	select  NULL as concept_id, a.code as concept_code, NULL as concept_name, a.code_type as vocabulary_id, a.code_description
	from Data_Concierge_Staging_PP.appendix_B a
	--join vocab.concept c on a.code = c.concept_code and c.vocabulary_id = ''
	where code_type = 'RV'



	--From Procedure_occurrence
	if OBJECT_ID('tempdb.dbo.#ALL_Treatments_proc') Is not null drop table #ALL_Treatments_proc
	select co.procedure_occurrence_id, co.person_id, co.procedure_concept_id, co.procedure_date,
	co.procedure_type_concept_id, co.quantity, co.visit_occurrence_id, co.procedure_source_value, 
	tr.vocabulary_id, co.procedure_source_concept_id
	into #ALL_Treatments_proc
	from #ALL_patients allp
	join omop5.procedure_occurrence co on co.person_id = allp.person_id 
	join #treatments tr on tr.concept_id = co.procedure_source_concept_id
	where co.procedure_date >= allp.condition_start_date
	group by co.procedure_occurrence_id, co.person_id, co.procedure_concept_id, co.procedure_date,
	co.procedure_type_concept_id, co.quantity, co.visit_occurrence_id, co.procedure_source_value,
	tr.vocabulary_id, co.procedure_source_concept_id


	--From Observation
	if OBJECT_ID('tempdb.dbo.#ALL_Treatments_obs') Is not null drop table #ALL_Treatments_obs
	select co.observation_id, co.person_id, co.observation_concept_id, co.observation_date,
	observation_type_concept_id, null as quantity,  co.visit_occurrence_id, co.observation_source_value,
	tr.vocabulary_id, co.observation_source_concept_id
	into #ALL_Treatments_obs
	from #ALL_patients allp
	join omop5.observation co on co.person_id = allp.person_id 
	join #treatments tr on tr.concept_id = co.observation_source_concept_id
	where co.observation_date >= allp.condition_start_date
	group by co.observation_id, co.person_id, co.observation_concept_id, co.observation_date,
	observation_type_concept_id, co.visit_occurrence_id, co.observation_source_value,
	tr.vocabulary_id, co.observation_source_concept_id


	--From Drug_Exposure 
	if OBJECT_ID('tempdb.dbo.#ALL_Treatments_drug') Is not null drop table #ALL_Treatments_drug
	select co.drug_exposure_id, co.person_id, co.drug_concept_id, co.drug_exposure_start_date,
	drug_type_concept_id, co.quantity,  co.visit_occurrence_id, co.drug_source_value,
	tr.vocabulary_id, co.drug_source_concept_id
	into #ALL_Treatments_drug
	from #ALL_patients allp
	join omop5.drug_exposure co on co.person_id = allp.person_id 
	join #treatments tr on tr.concept_id = co.drug_source_concept_id
	where co.drug_exposure_start_date >= allp.condition_start_date
	group by co.drug_exposure_id, co.person_id, co.drug_concept_id, co.drug_exposure_start_date,
	drug_type_concept_id, co.quantity,  co.visit_occurrence_id, co.drug_source_value,
	tr.vocabulary_id, co.drug_source_concept_id


	--Combine
	if OBJECT_ID('tempdb.dbo.#ALL_Treatments') Is not null drop table #ALL_Treatments
	select * into #ALL_treatments from #ALL_Treatments_proc
	union 
	select * from #ALL_Treatments_obs
	union 
	select * from #ALL_Treatments_drug 
	
	select * from #ALL_Treatments
