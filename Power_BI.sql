USE [EDDS1021751]
GO
/****** Object:  StoredProcedure [EDDSDBO].[PowerBI_Reports]    Script Date: 6/19/2020 3:03:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







ALTER procedure [EDDSDBO].[PowerBI_Reports] as

BEGIN
/*========================================================================================================================================================
                                                               DECLARATIONS                                                                   
========================================================================================================================================================*/

                declare @pivot_columns_comm AS NVARCHAR(MAX)
                declare @pivot_columns_L2 AS NVARCHAR(MAX)
				declare @sql nvarchar(max)
				declare @EndDate DATETIME SET @EndDate = (select getdate())
				declare @StartDate DATETIME SET @StartDate = @EndDate - 365
				declare @rule_name varchar(255)
				declare @rule_artifactid int 
				declare @StatusCompleted nvarchar(max) SET @StatusCompleted = 'Completed'
				declare @StatusPending nvarchar(max) SET @StatusPending = 'Pending'
				declare @StatusInProgress nvarchar(max) SET @StatusInProgress = 'In Progress'
				declare @unknown nvarchar(max) SET @unknown = 'Unknown' 
				declare @SecondLine nvarchar(max) SET @SecondLine = '%'+ '2L' + '%'
				----------------------------- Communication type field-------------------------------------

				declare @commtype_name nvarchar(max) SET @commtype_name = 'CommunicationType'
				declare @commtype_codetypeid int SET @commtype_codetypeid = (select CodeTypeID from eddsdbo.CodeType (nolock) where name = 'CommunicationType') --1000196 (Was commtype_zcode)
				declare @commtype_ztable nvarchar(max) set @commtype_ztable = (SELECT '[eddsdbo].zcodeartifact_' + CAST(CODETYPEID as nvarchar(100)) FROM [EDDSDBO].[CodeType] (nolock) WHERE [NAME] = @commtype_name) --[eddsdbo].zcodeartifact_1000196
				declare @commtype_chat nvarchar(max) SET @commtype_chat = 'Instant Message'

                ----------------------------------- 1L fields and choices ( heirarchy is Artifact - CodeType( ist line) - Code (escalate to second line, false positives))--------------------------------
               
				declare @decision1L_name nvarchar(max) SET @decision1L_name = 'R_1L-Decision'
                declare @decision1L_artifactid int set @decision1L_artifactid = (SELECT ArtifactID FROM [EDDSDBO].[Artifact] (nolock) WHERE [TextIdentifier] = @decision1L_name) -- 1055085
                declare @decision1L_codetypeid int set @decision1L_codetypeid = (SELECT CODETYPEID FROM [EDDSDBO].[CodeType] (nolock) WHERE DisplayName = @decision1L_name) -- 1000197
                declare @decision1L_escalate2L nvarchar(max) SET @decision1L_escalate2L = (SELECT ArtifactID FROM eddsdbo.code (nolock) where CodeTypeID = @decision1L_codetypeid AND name = 'Escalate to Second Line')-- 1055086
                declare @decision1L_FalsePositive nvarchar(max) SET @decision1L_FalsePositive = (SELECT ArtifactID FROM eddsdbo.code (nolock) where CodeTypeID = @decision1L_codetypeid AND name = 'False Positive')--1055087
                declare @decision1L_ztable varchar(max) SET @decision1L_ztable = (select '[eddsdbo].zcodeartifact_' + CAST(@decision1L_codetypeid AS nvarchar(25))) -- [eddsdbo].zcodeartifact_1000197

				 
				declare @decision1L_reason nvarchar(max) SET @decision1L_reason = 'R_1L-Reason'
				declare @decision1LReason_codetypeid int set @decision1LReason_codetypeid = (SELECT CODETYPEID FROM [EDDSDBO].[CodeType] (nolock) WHERE DisplayName = @decision1L_reason) -- 1000201
				declare @decision1LReason_ztable varchar(max) SET @decision1LReason_ztable = (select '[eddsdbo].zcodeartifact_' + CAST(@decision1LReason_codetypeid AS nvarchar(25))) -- [eddsdbo].zcodeartifact_1000201


                --------------------------------- 2L fields and choices------------------------------
                declare @decision2L_name nvarchar(max) SET @decision2L_name = 'R_2L-Decision'
                declare @decision2L_artifactid int set @decision2L_artifactid = (SELECT ArtifactID FROM [EDDSDBO].[Artifact] (nolock) WHERE [TextIdentifier] = @decision2L_name) -- 1055089
                declare @decision2L_codetypeid int set @decision2L_codetypeid = (SELECT CODETYPEID FROM [EDDSDBO].[CodeType] (nolock) WHERE DisplayName = @decision2L_name) -- 1000198
                declare @decision2L_FalsePositive nvarchar(max) SET @decision2L_FalsePositive = (SELECT ArtifactID FROM eddsdbo.code (nolock) where CodeTypeID = @decision2L_codetypeid AND name = 'False Positive - No Investigation') --1055092
				declare @decision2L_UnderInvestigation nvarchar(max) SET @decision2L_UnderInvestigation = (SELECT ArtifactID FROM eddsdbo.code (nolock) where CodeTypeID = @decision2L_codetypeid AND name = 'Under Investigation') --1055092
				declare @decision2L_LocalCompliance nvarchar(max) SET @decision2L_LocalCompliance = (SELECT ArtifactID FROM eddsdbo.code (nolock) where CodeTypeID = @decision2L_codetypeid AND name = 'Sent To Local Compliance') --1055092
                declare @decision2L_ztable varchar(max) SET @decision2L_ztable = (select '[eddsdbo].zcodeartifact_' + CAST(@decision2L_codetypeid AS nvarchar(25)))--[eddsdbo].zcodeartifact_1000198
                DECLARE @choice2L_artifact varchar(20)
                DECLARE @choice2L_name varchar(max)

				declare @decision2L_reason nvarchar(max) SET @decision2L_reason = 'R_2L-Reason'
				declare @decision2LReason_codetypeid int set @decision2LReason_codetypeid = (SELECT CODETYPEID FROM [EDDSDBO].[CodeType] (nolock) WHERE DisplayName = @decision2L_reason) -- 1000202
				declare @decision2LReason_ztable varchar(max) SET @decision2LReason_ztable = (select '[eddsdbo].zcodeartifact_' + CAST(@decision2LReason_codetypeid AS nvarchar(25))) -- [eddsdbo].zcodeartifact_1000202

                ----------------------------- Location type field-------------------------------------

                declare @location_name nvarchar(max) SET @location_name = 'CountryCode'
                declare @location_id int set @location_id = (select codetypeid from [EDDSDBO].codetype where name= @location_name)
				declare @location_ztable varchar(max) SET @location_ztable = (select '[eddsdbo].zcodeartifact_' + CAST(@location_id AS nvarchar(25)))--[eddsdbo].zcodeartifact_1000205
				
				----------------------------DOCUMENT (document and rule)------------------------------------------------
				--document -> rule
                declare @document_rule_ftable nvarchar(100)
                declare @document_rule_ftable_document_column_name nvarchar(100)
                declare @document_rule_ftable_rule_column_name nvarchar(100)
				
                -- document -> rule - create ftable string
                /*
				SELECT @document_rule_ftable =  'eddsdbo.f' + Stuff(
                  (SELECT N'f' + CAST(a. ArtifactID as nvarchar(20)) FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Rules' and (at.ArtifactType='Document' or at.ArtifactType='Rule') order by 1 
                  FOR XML PATH(''),TYPE)
                  .value('text()[1]','nvarchar(max)'),1,1,N'')
                */
				SELECT @document_rule_ftable = 'eddsdbo.f1046403f1046404'
                
                -- document -> rule - extract document artifact id column
                /*
				SELECT @document_rule_ftable_document_column_name = 'f' + CAST(a. ArtifactID as nvarchar(20)) + 'ArtifactID' FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Rules' and (at.ArtifactType='Document')  
                */
				SELECT @document_rule_ftable_document_column_name = 'f1046403ArtifactID'
				
                -- document -> rule - extract rule artifact id column
                /*
				SELECT @document_rule_ftable_rule_column_name = 'f' + CAST(a. ArtifactID as nvarchar(20)) + 'ArtifactID' FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Rules' and (at.ArtifactType='Rule')  
			*/
				SELECT @document_rule_ftable_rule_column_name = 'f1046404ArtifactID'
				------------------------------DOCUMENT TERM (document and term)------------------------------------------------
                --document -> term
                DECLARE @document_term_ftable nvarchar(100)
                DECLARE @document_term_ftable_term_column_name nvarchar(100)
                DECLARE @document_term_ftable_document_column_name nvarchar(100)

                -- document -> term - create ftable string
				/*
                SELECT @document_term_ftable =  'eddsdbo.f' + Stuff(
                  (SELECT N'f' + CAST(a. ArtifactID as nvarchar(20)) FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Document Term' and (at.ArtifactType='Document' or at.ArtifactType='Term') order by 1 
                  FOR XML PATH(''),TYPE)
                  .value('text()[1]','nvarchar(max)'),1,1,N'')
				  */
				SELECT @document_term_ftable = 'eddsdbo.f1046409f1046410'
				
                -- document -> term - extract document artifact id column
                /*
				SELECT @document_term_ftable_document_column_name = 'f' + CAST(a. ArtifactID as nvarchar(20)) + 'ArtifactID' FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Document Term' and (at.ArtifactType='Document')  
				*/
				SELECT @document_term_ftable_document_column_name = 'f1046409ArtifactID'
				
                -- document -> term - extract rule artifact id column
                /*
				SELECT @document_term_ftable_term_column_name = 'f' + CAST(a. ArtifactID as nvarchar(20)) + 'ArtifactID' FROM eddsdbo.artifact a (nolock) 
                               inner join eddsdbo.Field f (nolock) on a.ArtifactID=f.artifactid
                               inner join eddsdbo.ArtifactType at (nolock) on f.FieldArtifactTypeID = at.ArtifactTypeID
                               where a.TextIdentifier = 'Document Term' and (at.ArtifactType='Term')  
				*/
				SELECT @document_term_ftable_term_column_name = 'f1046410ArtifactID'
/*========================================================================================================================================================
                                                                 8) Delete tables                                                                              
========================================================================================================================================================*/
		

  IF OBJECT_ID('dbo.BatchDocumentCount', 'U') IS NOT NULL
    DROP TABLE dbo.BatchDocumentCount; 

  IF OBJECT_ID('dbo.CommType', 'U') IS NOT NULL
    DROP TABLE dbo.CommType; 

  IF OBJECT_ID('dbo.PBI_Decision1L', 'U') IS NOT NULL
    DROP TABLE dbo.PBI_Decision1L; 

  IF OBJECT_ID('dbo.PBI_Decision2L', 'U') IS NOT NULL
    DROP TABLE dbo.PBI_Decision2L; 
  
  IF OBJECT_ID('dbo.PBI_Decision2L_Unset', 'U') IS NOT NULL
    DROP TABLE dbo.PBI_Decision2L_Unset; 

  IF OBJECT_ID('dbo.PBI_Decision2L_Pending', 'U') IS NOT NULL
    DROP TABLE dbo.PBI_Decision2L_Pending; 

  IF OBJECT_ID('dbo.Relativity_Stats', 'U') IS NOT NULL
    DROP TABLE dbo.Relativity_Stats; 

  IF OBJECT_ID('dbo.alertSummaryPowerBI', 'U') IS NOT NULL
    DROP TABLE dbo.alertSummaryPowerBI; 
	
  IF OBJECT_ID('dbo.alertSummaryPowerBITemp', 'U') IS NOT NULL
    DROP TABLE dbo.alertSummaryPowerBITemp; 

  IF OBJECT_ID('dbo.alertSummaryPowerBIAnalyzed', 'U') IS NOT NULL
    DROP TABLE dbo.alertSummaryPowerBIAnalyzed; 
	
  IF OBJECT_ID('dbo.KeywordsPowerBI', 'U') IS NOT NULL
    DROP TABLE dbo.KeywordsPowerBI; 
	
  IF OBJECT_ID('dbo.RulesPowerBI', 'U') IS NOT NULL
    DROP TABLE dbo.RulesPowerBI; 
	
  IF OBJECT_ID('dbo.InvestigationPowerBI', 'U') IS NOT NULL
    DROP TABLE dbo.InvestigationPowerBI; 

/*========================================================================================================================================================
                                                               Second tab - Decision by Reason                                                                     
========================================================================================================================================================*/				 

 CREATE TABLE dbo.Relativity_Stats(
  Attribute  [nvarchar](200) NOT NULL,
  CodeType [nvarchar](200) NOT NULL,
  Createdon datetime,
  [Location] varchar(255),
  Count [int] NOT NULL) 

  -------------------------------------------------------------------------------------------------------
  -- Count of R_1L-Decision by R_1L-Reason
  SET @sql = '
											  insert into Relativity_Stats (Attribute, CodeType,Createdon,[Location], Count)
											  ( 
															SELECT ''' + CAST(  @decision1L_reason as nvarchar(20)) + ''', c.Name , CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ) ,count(zc.AssociatedArtifactID) as Count
																	  from ' + @decision1LReason_ztable + ' as  zc
																			inner join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID
																			left join [EDDS1021751].[EDDSDBO].[Code] c on zc.CodeArtifactID =c.ArtifactID
																			left join eddsdbo.document d on [zc].AssociatedArtifactID = d.ArtifactID
																			left join ' + @location_ztable + ' [c1] on d.EmailFromID = [c1].AssociatedArtifactID
																			left join eddsdbo.code cd on cd.artifactid = [c1].CodeArtifactID 
																			where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																			group by CAST(art.CreatedOn as DATE), c.Name, zc.CodeArtifactID,[cd].Name 
																	  
																	  )'
                                               execute(@sql)
  -----------------------------------------------------------------------------------------------
  -- Count of R_2L-Decision by R_2L-Reason

  SET @sql = '
											  insert into Relativity_Stats (Attribute, CodeType,Createdon,[Location], Count)
											  ( 
															SELECT ''' + CAST(  @decision2L_reason as nvarchar(20)) + ''', c.Name , CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ) ,count(zc.AssociatedArtifactID) as Count
																	  from ' + @decision2LReason_ztable + ' as  zc
																			inner join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID
																			left join [EDDS1021751].[EDDSDBO].[Code] c on zc.CodeArtifactID =c.ArtifactID
																			left join eddsdbo.document d on [zc].AssociatedArtifactID = d.ArtifactID
																			left join ' + @location_ztable + ' [c1] on d.EmailFromID = [c1].AssociatedArtifactID
																			left join eddsdbo.code cd on cd.artifactid = [c1].CodeArtifactID 
																			where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																			group by CAST(art.CreatedOn as DATE), c.Name, zc.CodeArtifactID,[cd].Name 
																	  
																	  )'
                                               execute(@sql)

/*========================================================================================================================================================
                                                              Decision 1L                                                                  
========================================================================================================================================================*/

CREATE TABLE dbo.PBI_Decision1L (
                                                   Metric varchar(255),
												   Createdon datetime,
												   [Location] varchar(255),
												   Commtype varchar(255),
                                                   Escalate2L int,
												   FalsePositives int,
												   Unset int
												 											   
                                               );
SET @sql = '
                                               INSERT INTO dbo.PBI_Decision1L (Metric, [Createdon],[Location],Commtype, Escalate2L,FalsePositives,Unset ) 
                                               (
                                                               SELECT ''Decision First Line'' as [Metric], CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
															                                  Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END),
                                                                                              escalate2L = COUNT (DISTINCT( CASE WHEN  zc.codeartifactid= ''' + CAST(@decision1L_escalate2L as nvarchar(20)) + ''' THEN zc.AssociatedArtifactID END)),
																							  FalsePositives =COUNT ( CASE WHEN zc.codeartifactid= ''' + CAST(@decision1L_FalsePositive as nvarchar(20)) + ''' THEN zc.AssociatedArtifactID END) ,
																							  0
                                                                              from  ' + @decision1L_ztable + ' as [zc]
																								inner join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on [zc].AssociatedArtifactID = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															 group by CAST(art.CreatedOn as DATE),[cd].Name ,[cd1].Name,CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END
                                               )'

                                           
                                               execute(@sql)




SET @sql = '
                                               INSERT INTO dbo.PBI_Decision1L (Metric, [Createdon],[Location],Commtype, Escalate2L,FalsePositives,Unset ) 
                                               (
                                                               SELECT ''Unset Alerts'' as [Metric], CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), 
															                   Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END) ,0,0,
															                   Unset = count(DISTINCT([t].' + @document_rule_ftable_document_column_name + '))                                   
                                                                         from ' + @document_rule_ftable + ' as [t] 
																								left join eddsdbo.Artifact art on [t]. ' + @document_rule_ftable_document_column_name + ' = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															 and ([t].' + @document_rule_ftable_document_column_name + ' not in (select [zc].AssociatedArtifactID from ' + @decision1L_ztable + ' as [zc]))
																															 group by CAST(art.CreatedOn as DATE),[cd].Name ,CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END
                                               )'

                                           
                                               execute(@sql)

/*========================================================================================================================================================
                                                              Decision 2L                                                              
========================================================================================================================================================*/

CREATE TABLE dbo.PBI_Decision2L                 (
                                                   Metric varchar(255),
												   Createdon datetime,
												   [Location] varchar(255),
												   Commtype varchar(255),
                                                   UnderInvestigation int,
												   FalsePositives int,
												   SentTo_LocalCompliance int,
												   Unset int,
												   Pending int
												   
                                               );

CREATE TABLE dbo.PBI_Decision2L_Unset          (
                                                 Artifactid int,
											     Createdon datetime   
                                               );

CREATE TABLE dbo.PBI_Decision2L_Pending          (
                                                 Artifactid int,
											     Createdon datetime   
                                               );

SET @sql = '
                                              INSERT INTO dbo.PBI_Decision2L (Metric, [Createdon],[Location],Commtype, UnderInvestigation,FalsePositives,SentTo_LocalCompliance,Unset,Pending ) 
                                               (
                                                               SELECT ''Decision Second Line'' as [Metric], CAST(art.Createdon as DATE),isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
															                                  Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END),
                                                                                              UnderInvestigation = COUNT (DISTINCT( CASE WHEN  zc.codeartifactid= ''' + CAST(@decision2L_UnderInvestigation as nvarchar(20)) + ''' THEN zc.AssociatedArtifactID END)),
																							  FalsePositives = COUNT (DISTINCT( CASE WHEN zc.codeartifactid= ''' + CAST(@decision2L_FalsePositive as nvarchar(20)) + ''' THEN zc.AssociatedArtifactID END)),
																							  SentTo_LocalCompliance = COUNT (DISTINCT( CASE WHEN zc.codeartifactid= ''' + CAST(@decision2L_LocalCompliance as nvarchar(20)) + ''' THEN zc.AssociatedArtifactID END)), 
																							  0,0
                                                                              from  ' + @decision2L_ztable + ' as [zc]
																								inner join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID     
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on [zc].AssociatedArtifactID = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                
                                                                                                                             where art.Createdon between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''																															 
																															 group by CAST(art.Createdon as DATE),[cd].Name, CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END 
                                               )'


                                           
                                               execute(@sql)



SET @sql = '
                                              INSERT INTO dbo.PBI_Decision2L_Unset (Artifactid,Createdon ) 
                                               (
                                                               SELECT d.documentartifactid, a1.CreatedOn
                                                                                from [EDDSDBO].[Batch] b 
																						inner join eddsdbo.artifact a on b.ArtifactID = a.ArtifactID
																						left join eddsdbo.DocumentBatch d on d.BatchArtifactID = a.ArtifactID
																						left join eddsdbo.artifact a1 on a1.ArtifactID = d.documentartifactid
																									where a1.CreatedOn between  ''' + CAST(@StartDate as varchar(30)) + ''' and ''' + CAST(@EndDate as varchar(30)) + '''
																									and b.StatusCodeArtifactID is NULL
																									and b.name like ''' + CAST( @SecondLine as nvarchar(20)) + '''
	
                                               )'
											   execute(@sql)

SET @sql = '
                                              INSERT INTO dbo.PBI_Decision2L_Pending (Artifactid,Createdon ) 
                                               (
                                                               SELECT d.documentartifactid, a1.CreatedOn
                                                                                from [EDDSDBO].[Batch] b 
																						inner join eddsdbo.artifact a on b.ArtifactID = a.ArtifactID
																						left join eddsdbo.DocumentBatch d on d.BatchArtifactID = a.ArtifactID
																						left join eddsdbo.artifact a1 on a1.ArtifactID = d.documentartifactid
																						left join eddsdbo.artifact s on b.StatusCodeArtifactID = s.ArtifactID
																									where a1.CreatedOn between  ''' + CAST(@StartDate as varchar(30)) + ''' and ''' + CAST(@EndDate as varchar(30)) + '''
																									and b.name like ''' + CAST( @SecondLine as nvarchar(20)) + '''
																									and s.TextIdentifier = ''' + CAST(@StatusInProgress as nvarchar(20)) + '''
	
                                               )'
                                           
                                               execute(@sql)

SET @sql = '
                                              INSERT INTO dbo.PBI_Decision2L (Metric, [Createdon],[Location],Commtype, UnderInvestigation,FalsePositives,SentTo_LocalCompliance,Unset,Pending ) 
                                               (
                                                               SELECT ''Unset Alerts'' as [Metric] , CAST(art.Createdon as DATE),isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
															                                  Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END),0,0,0,
                                                                                              Unset = count(u.Artifactid) , 0
                                                                              from  dbo.PBI_Decision2L_Unset [u]
																								inner join eddsdbo.Artifact art on [u].Artifactid = art.ArtifactID     
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on [art].ArtifactID = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                
                                                                                                                             where art.Createdon between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''																															 
																															 group by CAST(art.Createdon as DATE),[cd].Name, CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END 
                                               )'


                                           
                                               execute(@sql)

SET @sql = '
                                              INSERT INTO dbo.PBI_Decision2L (Metric, [Createdon],[Location],Commtype, UnderInvestigation,FalsePositives,SentTo_LocalCompliance,Unset,Pending ) 
                                               (
                                                               SELECT ''Unset Alerts'' as [Metric] , CAST(art.Createdon as DATE),isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
															                                  Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END),0,0,0,0,
                                                                                              Pending = count(p.Artifactid) 
                                                                              from  dbo.PBI_Decision2L_Pending [p]
																								inner join eddsdbo.Artifact art on [p].Artifactid = art.ArtifactID     
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on [art].ArtifactID = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                
                                                                                                                             where art.Createdon between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''																															 
																															 group by CAST(art.Createdon as DATE),[cd].Name, CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END 
                                               )'


                                           
                                               execute(@sql)


/*========================================================================================================================================================
                                                               Communication Type                                                                      
========================================================================================================================================================*/	



CREATE TABLE dbo.CommType (
                                                   
												   Createdon datetime,
                                                   CommType varchar(255),
												   [Location] varchar(255),
												   [Count] int
												   
												   
                                               );
			
SET @sql = '
						  INSERT INTO dbo.CommType ([Createdon],CommType,[Location],[Count] ) 
						  (
								select CAST(a.CreatedOn as DATE), 
								    Commtype = (CASE WHEN [c1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [c1].name END), 
								    isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), count(zc.AssociatedArtifactID) as [Count]
									from ' + @commtype_ztable + ' as [zc] 
										inner join [EDDSDBO].[Artifact] a on [zc].AssociatedArtifactID = a.ArtifactID
										left join eddsdbo.code c1 on c1.artifactid = [zc].CodeArtifactID
										left join eddsdbo.document d on [zc].AssociatedArtifactID = d.ArtifactID
										left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
										left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
						
											where a.CreatedOn between ''' + CAST(@StartDate as varchar(30)) + ''' and ''' + CAST(@EndDate as varchar(30)) + '''
											group by CAST(a.CreatedOn as DATE), cd.name, CASE WHEN [c1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [c1].name END
						  
						  )'
						  execute(@sql)
  
					

/*========================================================================================================================================================
                                                                Batches                                                                      
========================================================================================================================================================*/	

 CREATE TABLE dbo.BatchDocumentCount (
                                                   
												   Batch varchar(255),
                                                   ArtifactID int,
												   CreatedOn datetime,
												   [Status] varchar(255),
												   [Count] int
												   );
SET @sql = '
						   INSERT INTO dbo.BatchDocumentCount (Batch, ArtifactID,[CreatedOn],[Status],[Count] ) 
						   (                                              
							select a.TextIdentifier as "Batch", a.ArtifactID , a.CreatedOn, 
							Status = (CASE WHEN s.TextIdentifier = ''' + CAST(@StatusCompleted as nvarchar(20)) + ''' THEN  s.TextIdentifier 
											WHEN s.TextIdentifier = ''' + CAST(@StatusInProgress as nvarchar(20)) + ''' THEN  s.TextIdentifier
											ELSE ''' + CAST(@StatusPending as nvarchar(20)) + ''' END),
							Count(d.documentartifactid) As "DocumentCount"
							from [EDDSDBO].[Batch] b 
							inner join eddsdbo.artifact a on b.ArtifactID = a.ArtifactID
							left join eddsdbo.DocumentBatch d on d.BatchArtifactID = a.ArtifactID
							left join eddsdbo.artifact s on b.StatusCodeArtifactID = s.ArtifactID
							where a.CreatedOn between  ''' + CAST(@StartDate as varchar(30)) + ''' and ''' + CAST(@EndDate as varchar(30)) + '''
							group by a.TextIdentifier, a.ArtifactID , a.CreatedOn, (CASE WHEN s.TextIdentifier = ''' + CAST(@StatusCompleted as nvarchar(20)) + ''' THEN  s.TextIdentifier 
											WHEN s.TextIdentifier = ''' + CAST(@StatusInProgress as nvarchar(20)) + ''' THEN  s.TextIdentifier
											ELSE ''' + CAST(@StatusPending as nvarchar(20)) + ''' END)
	
							)'
						   execute(@sql)
	
	

/*========================================================================================================================================================
														Overview- Number of alerts raised  (distinct documents)                                                                                                                                    
========================================================================================================================================================*/



CREATE TABLE dbo.alertSummaryPowerBI (
                                                   Metric varchar(255),
												   TraceRule varchar(255),
												   Createdon datetime,
												   [Location] varchar(255),
												   CommType varchar(255),
                                                   [Count] int,
                                                   --[Order] int,
												   
                                               );

											   CREATE TABLE dbo.alertSummaryPowerBITemp (
											       Artifactid int,
												   TraceRule varchar(255),
                                                   Createdon datetime,
												   [Location] varchar(255),
												   CommType varchar(255),
                                                   
                                                   --[Order] int,
												   
                                               );
	
SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBITemp (Artifactid ,TraceRule ,[Createdon],[Location],CommType) 
											  (
															  
																select [t].' + @document_rule_ftable_document_column_name + ',r.Name, CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END)
                                                                                                                
																			from ' + @document_rule_ftable + ' as [t]
																			                    left join eddsdbo.[Rule] r on r.artifactid = t. '+@document_rule_ftable_rule_column_name+'
																								left join eddsdbo.Artifact art on [t]. ' + @document_rule_ftable_rule_column_name + ' = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															  
											)'

																															  
												execute(@sql)
SET @sql = '														
                                                    INSERT INTO dbo.alertSummaryPowerBITemp (Artifactid,TraceRule, [Createdon],[Location],CommType) 
											  (                     

																		select [zc].AssociatedArtifactID,r.Name ,  CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END)                                    
																			from ' + @decision1L_ztable + ' as [zc]
																								left join ' + @document_rule_ftable + ' as [t] on zc.AssociatedArtifactID = t. '+@document_rule_ftable_document_column_name+'
																								LEFT join eddsdbo.[Rule] r on r.artifactid = t.  ' + @document_rule_ftable_rule_column_name + '
																								left join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															

											  )'

											  execute(@sql)


SET @sql = '														
                                                    INSERT INTO dbo.alertSummaryPowerBITemp (Artifactid, TraceRule ,[Createdon],[Location],CommType) 
											  (                     

																		select [zc].AssociatedArtifactID, r.Name, CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END)                                    
																			from ' + @decision2L_ztable + ' as [zc] 
																								left join ' + @document_rule_ftable + ' as [t] on zc.AssociatedArtifactID = t. '+@document_rule_ftable_document_column_name+'
																								LEFT join eddsdbo.[Rule] r on r.artifactid = t.  ' + @document_rule_ftable_rule_column_name + '
																								left join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															

											  )'

											  execute(@sql)

SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBI (Metric,TraceRule,[Createdon],[Location],CommType, [Count]) 
											  (
															  SELECT ''Number of alerts raised'' as [Metric], TraceRule, [Createdon],[Location],CommType,
															                   count(DISTINCT Artifactid) as [Count]
																			   from dbo.alertSummaryPowerBITemp
																			   group by TraceRule,[Createdon],[Location],CommType
																			   )'
																			

											  execute(@sql)


/*========================================================================================================================================================
													Overview - Number of alerts analysed                                                                                                                             
========================================================================================================================================================*/

  CREATE TABLE dbo.alertSummaryPowerBIAnalyzed (
											       Artifactid int,
												   TraceRule varchar(255),
                                                   Createdon datetime,
												   [Location] varchar(255),
												   CommType varchar(255),
                                                   
                                                   --[Order] int,
												   
                                               );

SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBIAnalyzed (ArtifactID,TraceRule,[Createdon],[Location],CommType) 
											  (
															  SELECT [zc].AssociatedArtifactID,r.Name, CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END)
                                                     
																			from ' + @decision1L_ztable + ' as [zc]
																								left join ' + @document_rule_ftable + ' as [t] on zc.AssociatedArtifactID = t. '+@document_rule_ftable_document_column_name+'
																								left join eddsdbo.[Rule] r on r.artifactid = t. ' + @document_rule_ftable_rule_column_name + '
																								left join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															
											  )'

											  execute(@sql)

SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBIAnalyzed (ArtifactID,TraceRule,[Createdon],[Location],CommType) 
											  (
															  SELECT [zc].AssociatedArtifactID, r.Name,CAST(art.CreatedOn as DATE), isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ), Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END)
                                                     
																			from ' + @decision2L_ztable + ' as [zc] 
																								left join ' + @document_rule_ftable + ' as [t] on zc.AssociatedArtifactID = t. '+@document_rule_ftable_document_column_name+'
																								left join eddsdbo.[Rule] r on r.artifactid = t. ' + @document_rule_ftable_rule_column_name + '
																								left join eddsdbo.Artifact art on [zc].AssociatedArtifactID = art.ArtifactID  
																								left join ' + @commtype_ztable + ' as [cm] on cm.AssociatedArtifactID = art.ArtifactID
																								left join eddsdbo.code cd1 on cd1.artifactid = [cm].CodeArtifactID 
																								left join eddsdbo.document d on  art.ArtifactID  = d.ArtifactID
																								left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																								left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																							                                 where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																															 
											  )'

											  execute(@sql)

SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBI (Metric,TraceRule,[Createdon],[Location],CommType, [Count]) 
											  (
															  SELECT ''Number of alerts analyzed'' as [Metric], TraceRule,[Createdon],[Location],CommType,
															                   count(DISTINCT Artifactid) as [Count]
																			   from dbo.alertSummaryPowerBIAnalyzed
																			   group by TraceRule,[Createdon],[Location],CommType
																			   )'
																			

											  execute(@sql)


/*========================================================================================================================================================
													Overview - Number of documents analysed                                                                                                                             
========================================================================================================================================================*/

			
SET @sql = '
											  INSERT INTO dbo.alertSummaryPowerBI (Metric,[TraceRule],[Createdon],[Location],CommType,[Count] ) 
											  (
											  select ''Number of documents analysed'' as [Metric], ''DocumentAnalysed'' as [TraceRule] ,CAST(a.CreatedOn as DATE),isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
											                Commtype = (CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END), count(zc.AssociatedArtifactID) as [Count]
															from ' + @commtype_ztable + ' as [zc]
																													left join eddsdbo.Artifact a on [zc].AssociatedArtifactID = a.ArtifactID  
																													left join eddsdbo.code cd1 on cd1.artifactid = [zc].CodeArtifactID 
																													left join eddsdbo.document d on  a.ArtifactID  = d.ArtifactID
																													left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																													left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
						  						  
											  where a.CreatedOn between ''' + CAST(@StartDate as varchar(30)) + ''' and ''' + CAST(@EndDate as varchar(30)) + '''
											  group by CAST(a.CreatedOn as DATE),CASE WHEN [cd1].Name =''' + CAST( @commtype_chat as nvarchar(20)) + ''' THEN d.IVSource ELSE [cd1].name END, cd.Name
						  
											  )'
											  execute(@sql)

/*========================================================================================================================================================
																Keywords                                                                                                                     
========================================================================================================================================================*/


CREATE TABLE dbo.KeywordsPowerBI (		           Metric varchar(255),
                                                   Keyword nvarchar(255),
												   [Rule] varchar(255),
												   [Location] varchar(255),
												   [Count] int,
                                                   Createdon datetime
                                               );

SET @sql = '
											  INSERT INTO dbo.KeywordsPowerBI (Metric, Keyword, [Rule],[Location], [Count], Createdon) 
											  (
															  SELECT ''Term hits'' as [Metric], t.name,r.Name,isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
																							 count(DISTINCT (dt_ftable.' + @document_term_ftable_document_column_name + ')),
																							 CAST(art.CreatedOn as DATE)
																			 from ' + @document_term_ftable + ' dt_ftable (nolock) 
																							 inner join ' + @document_rule_ftable + ' dr_ftable on dt_ftable.' + @document_term_ftable_document_column_name + ' = dr_ftable. ' + @document_rule_ftable_document_column_name + '
																							 inner join eddsdbo.[Rule] r on r.artifactid = dr_ftable.' + @document_rule_ftable_rule_column_name + '
																							 inner join eddsdbo.Term t on t.artifactid = dt_ftable.' + @document_term_ftable_term_column_name + '
																							 inner join eddsdbo.Artifact art (nolock) on dt_ftable.' + @document_term_ftable_document_column_name + ' = art.ArtifactID
																							 inner join eddsdbo.document d on dt_ftable.' + @document_term_ftable_document_column_name + ' = d.ArtifactID
																							 inner join eddsdbo.DocumentBatch db on db.DocumentArtifactID=d.ArtifactID
																							 inner join eddsdbo.Batch b on db.BatchArtifactID=b.ArtifactID
																							 inner join eddsdbo.BatchSet  bs on b.BatchSetArtifactID=bs.ArtifactID
																							 left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																							 left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																			
																														where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + ''' and r.Name != ''ING_UKCodeConductList_Rule''
																														and bs.[name] in (''BS_1L_Rules_Email'',''BS_1L_Rules_Chat_Bloomberg'',''BS_1L_Rules_Chat_Reuters'',''BS_2L_Rules_Email'',''BS_2L_Direct_Voice'',''BS_2L_Rules_Chat_Bloomberg'',''BS_2L_Rules_Chat_Reuters'')
																														group by CAST(art.CreatedOn as DATE), t.name, r.Name, [cd].Name 
											  )'

											  execute(@sql)


/*========================================================================================================================================================
															Rules                                                                                                                     
========================================================================================================================================================*/



CREATE TABLE dbo.RulesPowerBI (		   Metric varchar(255),
                                                   [Rule] varchar(255),
												   [Location] varchar(255),
												   [Count] int,
                                                   Createdon datetime
                                               );

SET @sql = '
											  INSERT INTO dbo.RulesPowerBI (Metric, [Rule],[Location], [Count], Createdon) 
											  (
															  SELECT ''Rule hits'' as [Metric], r.Name, isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' ),
																							 count(DISTINCT (dt_ftable.' + @document_rule_ftable_document_column_name + ')),
																							 CAST(art.CreatedOn as DATE)
																			 from ' + @document_rule_ftable + ' dt_ftable (nolock) 
																							 left join eddsdbo.[Rule] r on r.artifactid = dt_ftable. ' + @document_rule_ftable_rule_column_name + '
																							 left join eddsdbo.Artifact art (nolock) on dt_ftable.' + @document_rule_ftable_document_column_name + ' = art.ArtifactID
																							 left join eddsdbo.document d on dt_ftable.' + @document_rule_ftable_document_column_name + ' = d.ArtifactID
																							 left join ' + @location_ztable + ' [c] on d.EmailFromID = [c].AssociatedArtifactID
																							 left join eddsdbo.code cd on cd.artifactid = [c].CodeArtifactID 
																			
																														where art.CreatedOn between ''' + CAST(@startDate as varchar(30)) + ''' and ''' + CAST(@endDate as varchar(30)) + '''
																														group by CAST(art.CreatedOn as DATE), r.name,  [cd].Name 
											  )'

											  execute(@sql)


/*========================================================================================================================================================
															Investigation                                                                                                                     
========================================================================================================================================================*/


CREATE TABLE dbo.InvestigationPowerBI(
									  [Name] nvarchar(255) null,
									  [Owner] nvarchar(255) null,
									  Createdon datetime,
									  [Status] nvarchar(255),
									  [Description]  nvarchar(max) null,
									  FalsePositiveComment nvarchar(max) null,
									  TruePositiveComment nvarchar(max) null,
									  InitialDocument int,
									  DocumentDate datetime,
									  InvestigationNote nvarchar(max),
									  NoteCreatedOn datetime,
									  [Location] varchar(255))
  



 SET @sql = '
 
									INSERT into dbo.InvestigationPowerBI ([Name],[Owner],[Createdon],[Status],[Description],FalsePositiveComment,TruePositiveComment, 
											InitialDocument , DocumentDate,InvestigationNote, NoteCreatedOn, [Location] ) (
  
   
									SELECT i.[Name], i.[Owner_Text], a1.Createdon, c.Name,SUBSTRING(i.[Description],1,100) ,SUBSTRING(i.FalsePositiveComment,1,100),SUBSTRING( i.TruePositiveComment,1,100), 
												d.ControlNumber , a.CreatedOn, SUBSTRING(inn.note,1,100), a2.Createdon, isnull([cd].name,''' + CAST(@Unknown as nvarchar(20)) + ''' )
															from eddsdbo.Investigation i 
																						left join eddsdbo.Artifact a1 on i.ArtifactID =a1.ArtifactID
																						left join eddsdbo.Artifact a on i.InitialDocumentID =a.ArtifactID
																						left join eddsdbo.document d on a.ArtifactID=d.ArtifactID
																						left join ' + @location_ztable + ' [c1] on d.EmailFromID = [c1].AssociatedArtifactID
																						left join eddsdbo.code cd on cd.artifactid = [c1].CodeArtifactID 																							                                
																						left join eddsdbo.Artifact a2 on a2.ParentArtifactID = a1.ArtifactID
																						left join eddsdbo.InvestigationNote inn on a2.ArtifactID = inn.ArtifactID
																						left join eddsdbo.zcodeartifact_1000199 [z] on i.ArtifactID = [z].AssociatedArtifactID
																						left join eddsdbo.code c on c.artifactid = [z].codeartifactid
				
								 )' 
								 
						 execute(@sql)


   END
