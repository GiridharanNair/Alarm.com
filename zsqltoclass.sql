
GO
/****** Object:  StoredProcedure [dbo].[zSqlToClass]    Script Date: 10/25/2022 8:08:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[zSqlToClass]
    @ReturnEntities bit = 1,
    @IncludeInterface bit = 0,
    @ReturnDataContext bit = 1,
    @ClassName varchar(100) = 'ToteCustomerPortalDataContext',
    @ClassNamespace varchar(100) = 'CustomerPortal.Models',
    @BaseClassName varchar(100) = 'SqlDataContext',
    @BaseClassNamespace varchar(100) = 'Tote.Utils',
    @ConnectionStringName varchar(200) = 'ToteMaritimeConnectionString',
    @IgnoreEntities varchar(8000) = 'zCheckSchema,zSqlToClass'
AS

SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;

DROP PROCEDURE IF EXISTS dbo.sp_alterdiagram;  
DROP PROCEDURE IF EXISTS dbo.sp_creatediagram;  
DROP PROCEDURE IF EXISTS dbo.sp_dropdiagram; 
DROP PROCEDURE IF EXISTS dbo.sp_helpdiagramdefinition; 
DROP PROCEDURE IF EXISTS dbo.sp_renamediagram; 
DROP PROCEDURE IF EXISTS dbo.sp_upgraddiagrams; 
DROP PROCEDURE IF EXISTS dbo.sp_helpdiagrams;
DROP FUNCTION IF EXISTS dbo.fn_diagramobjects;
DROP TABLE IF EXISTS dbo.sysdiagrams;

DECLARE @NewLine varchar(2) = CHAR(13) + CHAR(10), @2NewLines varchar(4) = CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
DECLARE @DataTypes table (KeyID int, IsNullable bit, SqlName varchar(100), CName varchar(100), SqlDbType varchar(100))
DECLARE @StoredProceduresReturnClasses table (EntityName varchar(100), Line varchar(8000), Ignore bit)
DECLARE @EntityLines table (EntityType varchar(10), EntityName varchar(100), InterfaceSignature varchar(2000), Line varchar(8000), Ignore bit)
DECLARE @IgnoreEntitiesList table (Entity varchar(100))

Insert into @IgnoreEntitiesList
SELECT REPLACE(LTRIM(RTRIM(value)), @NewLine, '') FROM string_split(@IgnoreEntities, ',')

Insert into @DataTypes (KeyID, SqlName, IsNullable)
Select system_type_id, name, 0 As IsNullable from sys.types where system_type_id = user_type_id

Insert into @DataTypes (KeyID, SqlName, IsNullable)
Select system_type_id, name, 1 As IsNullable from sys.types where system_type_id = user_type_id

Update @DataTypes set CName='bool', SqlDbType = 'Bit' where SqlName in ('bit')
Update @DataTypes set CName='Byte[]', SqlDbType = 'Binary' where SqlName in ('binary','timestamp','varbinary')
Update @DataTypes set CName='DateTime', SqlDbType = 'DateTime' where SqlName in ('date','datetime','datetime2','smalldatetime')
Update @DataTypes set CName='DateTimeOffset', SqlDbType = 'DateTimeOffset' where SqlName in ('datetimeoffset')
Update @DataTypes set CName='decimal', SqlDbType = 'Decimal' where SqlName in ('decimal','money','numeric','smallmoney')
Update @DataTypes set CName='double', SqlDbType = 'Float' where SqlName in ('float')
Update @DataTypes set CName='Guid', SqlDbType = 'UniqueIdentifier' where SqlName in ('uniqueidentifier')
Update @DataTypes set CName='int', SqlDbType = 'Int' where SqlName in ('int')
Update @DataTypes set CName='int', SqlDbType = 'SmallInt' where SqlName in ('smallint')
Update @DataTypes set CName='int', SqlDbType = 'TinyInt' where SqlName in ('tinyint')
Update @DataTypes set CName='long', SqlDbType = 'BigInt' where SqlName in ('bigint')
Update @DataTypes set CName='Single', SqlDbType = 'Real' where SqlName in ('real')
Update @DataTypes set CName='TimeSpan', SqlDbType = 'Time' where SqlName in ('time')
Update @DataTypes set CName = CName + '?' where IsNullable = 1
Update @DataTypes set CName = 'string', SqlDbType = 'VarChar' where CName is null
Update @DataTypes set SqlDbType = 'SqlDbType.' + SqlDbType

--Result Classes
Insert into @StoredProceduresReturnClasses
Select SP.name, 'public partial class ' + SP.name + 'Result ' + @NewLine + '{ ' + @NewLine + 
STUFF((Select CHAR(10) +
		--Case When r.is_nullable = 1 Then '' Else CHAR(10) + '[Required(ErrorMessage = "* Required Field", AllowEmptyStrings = false)]' + CHAR(10) End +
		'public ' + DT.CName + ' ' + r.name + ' { get; set; }'
		FROM sys.objects P1
		CROSS APPLY sys.dm_exec_describe_first_result_set_for_object(P1.object_id, 0) r
		Join @DataTypes DT on DT.KeyID = r.system_type_id And DT.IsNullable = r.is_nullable
		Where P1.name = SP.name
		Order by r.column_ordinal
		FOR XML PATH('')), 1, 1, '') + @NewLine + ' }' + @2NewLines As ClassLine,
0 as Ignore
from sys.procedures SP
Where SP.name <> 'zSqlToClass'

Delete from @StoredProceduresReturnClasses where Line is null

--Stored Procedures
Insert into @EntityLines (EntityType, EntityName, Line, Ignore)
SELECT EN.type, EN.name, 'public ' +
Case When CL.EntityName is not null Then 'List<' + EN.name + 'Result> ' Else 'void ' End
+ EN.name + '(' +
COALESCE(STUFF((Select ', ' + Case When IP.is_output = 1 Then 'ref ' Else '' End + IDT.CName + ' ' + REPLACE(IP.name, '@', '') 
		FROM sys.objects E1
		Join sys.parameters IP ON IP.OBJECT_ID = E1.OBJECT_ID
		Join @DataTypes IDT on IDT.KeyID = IP.system_type_id And IDT.IsNullable = IP.is_nullable
		Where E1.name = EN.name
		And IP.name not in ('@EnvID', '@UserID', '@UserTokenID')
		Order by IP.parameter_id
		FOR XML PATH('')), 1, 1, ''), '') +
Case When CL.EntityName is not null Then ')' +  + @NewLine + '{' +  + @NewLine + 'return ExecuteProcedure<' + EN.name + 'Result>' Else ') { ExecuteProcedure' End +
		'("' + SC.name + '.' + EN.name + '", ' +
COALESCE(STUFF((Select ',' + '("' + IP.name + '", ' + REPLACE(IP.name, '@', '') + ', ' + IDT.SqlDbType + ')'
		FROM sys.objects E1
		Join sys.parameters IP ON IP.OBJECT_ID = E1.OBJECT_ID
		Join @DataTypes IDT on IDT.KeyID = IP.system_type_id And IDT.IsNullable = IP.is_nullable
		Where E1.name = EN.name
		Order by IP.parameter_id
		FOR XML PATH('')), 1, 1, ''), '') 
		+ ');' + @NewLine +  '}' + @2NewLines AS EntityLine,
0 As Ignore
FROM sys.objects EN
Join sys.schemas SC on SC.schema_id = EN.schema_id
Left Join @StoredProceduresReturnClasses CL on CL.EntityName = EN.name
WHERE EN.TYPE in ('P', 'IF')
ORDER BY EN.name

--Functions
Insert into @EntityLines (EntityType, EntityName, Line, Ignore)
SELECT EN.type, EN.name, 'public ' + DTO.CName + ' ' + EN.name + '(' + 
COALESCE(STUFF((Select ',' + DT.CName + ' ' + REPLACE(PI.name, '@', '') 
		FROM sys.objects ET
		Join sys.parameters PI ON ET.OBJECT_ID = PI.OBJECT_ID And PI.is_output = 0
		Join @DataTypes DT on DT.KeyID = PI.system_type_id And DT.IsNullable = PI.is_nullable
		Where ET.name = EN.name
		And PI.name not in ('@EnvID', '@UserID', '@UserTokenID')
		Order by PI.parameter_id
		FOR XML PATH('')), 1, 1, ''), '') + ')' 
		+  + @NewLine + ' {' +  + @NewLine + 'return (' + DTO.CName + ')ExecuteScalarFunction("' + SC.name + '.' + EN.name + '", ' +
COALESCE(STUFF((Select ',' + '("' + PI.name + '", ' + REPLACE(PI.name, '@', '') + ', ' + DT.SqlDbType + ')'
		FROM sys.objects ET
		Join sys.parameters PI ON ET.OBJECT_ID = PI.OBJECT_ID And PI.is_output = 0
		Join @DataTypes DT on DT.KeyID = PI.system_type_id And DT.IsNullable = PI.is_nullable
		Where ET.name = EN.name
		Order by PI.parameter_id
		FOR XML PATH('')), 1, 1, ''), '') 
		+ ');' + @NewLine + '}' + @2NewLines As EntityLine,
0 As Ignore
FROM sys.objects EN
Join sys.schemas SC on SC.schema_id = EN.schema_id
Left Join sys.parameters PO ON EN.OBJECT_ID = PO.OBJECT_ID And PO.is_output = 1
Left Join @DataTypes DTO on DTO.KeyID = PO.system_type_id And DTO.IsNullable = PO.is_nullable
WHERE EN.TYPE = 'FN'
ORDER BY EN.name

Update EL
Set EL.Ignore = 1
from @EntityLines EL
Join @IgnoreEntitiesList IE on IE.Entity = EL.EntityName

Update RC
Set RC.Ignore = 1
from @StoredProceduresReturnClasses RC
Join @IgnoreEntitiesList IE on IE.Entity = RC.EntityName

Update @EntityLines set Line = REPLACE(Line, ', )', ')')
Update @EntityLines Set InterfaceSignature = SUBSTRING(Line, 0, CHARINDEX(')', Line) + 1) + ';'
Update @EntityLines Set InterfaceSignature = REPLACE(InterfaceSignature, 'public ', '')

IF @ReturnEntities = 0
BEGIN
	DECLARE @Class varchar(max)

	Select @Class = 'using System;' + @NewLine 
				+ 'using System.Data;' + @NewLine 
				+ 'using System.Collections.Generic;' + @NewLine
				+ 'using System.ComponentModel.DataAnnotations;' + @NewLine
				+ 'using Microsoft.Extensions.Configuration;' + @NewLine
				+ 'using Microsoft.AspNetCore.Http;' + @NewLine
				+ 'using Microsoft.AspNetCore.Components;' + @NewLine
				+ 'using Microsoft.AspNetCore.Components.Authorization;' + @NewLine
				+ 'using ' +  @BaseClassNamespace + ';' + @2NewLines				--Base Class namespace
				+ 'namespace ' + @ClassNamespace + @NewLine											--Current namespace
				+ '{' + @NewLine 
	--Interface
	IF @IncludeInterface = 1
	BEGIN
		Select @Class = @Class + 'public interface I' + @ClassName + @NewLine						--Interface Name
					+ '{' + @NewLine 

		Select @Class = @Class + '#region Procedures' + @2NewLines
		Select @Class = @Class + InterfaceSignature + @NewLine from @EntityLines Where EntityType = 'P' And Ignore = 0 order by EntityType desc, EntityName
		Select @Class = @Class + @NewLine + '#endregion' + @2NewLines
		Select @Class = @Class + '#region Table Functions' + @2NewLines
		Select @Class = @Class + InterfaceSignature + @NewLine from @EntityLines Where EntityType = 'IF' And Ignore = 0 order by EntityType desc, EntityName
		Select @Class = @Class + @NewLine + '#endregion' + @2NewLines
		Select @Class = @Class + '#region Scalar Functions' + @2NewLines
		Select @Class = @Class + InterfaceSignature + @NewLine from @EntityLines Where EntityType = 'FN' And Ignore = 0 order by EntityType desc, EntityName
		Select @Class = @Class + @NewLine + '#endregion' + @2NewLines

		Select @Class = @Class + '}' + @2NewLines 
	END

	--Class
	Select @Class = @Class + 'public partial class ' + @ClassName + ' : ' + @BaseClassName								--Class Name
				+ Case When @IncludeInterface = 1 Then ', I' + @ClassName Else '' End + @NewLine		--Interface Name
				+ '{' + @NewLine 
				+ 'public ' + @ClassName + '(AuthenticationStateProvider authenticationStateProvider, NavigationManager navManager, IConfiguration configuration) : base(authenticationStateProvider, navManager, configuration, "' + @ConnectionStringName + '")' + @NewLine 
				+ '{' + @NewLine 
				+ '}' + @2NewLines 
				Where @ReturnEntities = 0

	Select @Class = @Class + '#region Procedures' + @2NewLines
	Select @Class = @Class + Line from @EntityLines Where EntityType = 'P' And Ignore = 0 order by EntityType desc, EntityName
	Select @Class = @Class + '#endregion' + @2NewLines
	Select @Class = @Class + '#region Table Functions' + @2NewLines
	Select @Class = @Class + Line from @EntityLines Where EntityType = 'IF' And Ignore = 0 order by EntityType desc, EntityName
	Select @Class = @Class + '#endregion' + @2NewLines
	Select @Class = @Class + '#region Scalar Functions' + @2NewLines
	Select @Class = @Class + Line from @EntityLines Where EntityType = 'FN' And Ignore = 0 order by EntityType desc, EntityName
	Select @Class = @Class + '#endregion' + @2NewLines
	Select @Class = @Class + '}' +  @2NewLines
	Select @Class = @Class + Line from @StoredProceduresReturnClasses Where Ignore = 0 Order by EntityName
	Select @Class = @Class + '}'

	DECLARE @RowCount int, @CurrentRowNumber INT = 1, @Line varchar(2000)
	DECLARE @Lines table (LineNumber int, LineContent varchar(2000))

	Insert into @Lines (LineNumber, LineContent)
	Select ROW_NUMBER() over (order by (Select 1)), value from string_split(@Class, CHAR(13))
	Select @RowCount = count(0) from @Lines

	WHILE @CurrentRowNumber <= @RowCount
	BEGIN
		Select @Line = LineContent from @Lines where LineNumber = @CurrentRowNumber
		PRINT @Line
		Select @CurrentRowNumber = @CurrentRowNumber + 1
	END

	Select @Class
END
ELSE
BEGIN
	Select * from @EntityLines
	order by EntityType desc, EntityName

	Select * from @StoredProceduresReturnClasses
	Order by EntityName
END
