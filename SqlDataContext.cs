using System;
using System.Linq;
using System.Data;
using System.Reflection;
using System.Collections.Generic;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Http;

namespace Cardinal.Utils
{
    public class SqlDataContext
    {
        protected string ConnectionString { get; set; }
        //public HttpContext CurrentHttpContext;

        protected SqlDataContext(IConfiguration configuration, IHttpContextAccessor httpContext, string connectionStringName)
        {
            if (httpContext.HttpContext != null)
            {
                EnvHelper envHelper = new EnvHelper();
                int portalID = envHelper.PortalID(httpContext.HttpContext);
                if(portalID == 2) connectionStringName = "Returns3PLConnectionString";
            }
            ConnectionString = configuration.GetConnectionString(connectionStringName);
            if (!ConnectionString.Contains("Pooling")) throw new Exception("Connections without pooling is not supported");
        }

        /// <summary>
        /// Execute Stored Procedure
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="procedureName"></param>
        /// <param name="parameters"></param>
        /// <returns>List of records</returns>
        protected List<T> ExecuteProcedure<T>(string procedureName, params (string paramName, dynamic paramValue, SqlDbType paramSqlDbType)[] parameters)
        {
            List<T> records = new List<T>();
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(procedureName, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    foreach ((string paramName, dynamic paramValue, SqlDbType paramSqlDbType) parameter in parameters)
                    {
                        SqlParameter param = command.Parameters.Add(parameter.paramName, parameter.paramSqlDbType);
                        param.IsNullable = true;
                        if (parameter.paramValue != null) param.Value = parameter.paramValue; else param.Value = DBNull.Value;
                    }
                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        //map only common fields between the Object and DataReader response
                        List<PropertyInfo> objectProperties = typeof(T).GetProperties().ToList();
                        Dictionary<PropertyInfo, string> mapFields = new Dictionary<PropertyInfo, string>();
                        for (int i = 0; i < reader.FieldCount; i++)
                        {
                            string dataColumnName = reader.GetName(i);
                            if (objectProperties.Where(x => x.Name == dataColumnName).Count() > 0)
                            {
                                mapFields.Add(objectProperties.First(x => x.Name == dataColumnName), reader.GetDataTypeName(i));
                            }
                        }

                        while (reader.Read())
                        {
                            var record = Activator.CreateInstance<T>();
                            foreach (KeyValuePair<PropertyInfo, string> mapField in mapFields)
                            {
                                if (reader[mapField.Key.Name] != DBNull.Value)
                                {
                                    switch (mapField.Value)
                                    {
                                        case "tinyint":
                                        case "smallint":
                                            mapField.Key.SetValue(record, Convert.ToInt32(reader[mapField.Key.Name]));
                                            break;
                                        default:
                                            mapField.Key.SetValue(record, reader[mapField.Key.Name]);
                                            break;
                                    }
                                }
                            }

                            records.Add(record);
                        }
                    }
                }
            }

            return records;
        }

        private void CheckParam(object paramValue)
        {
            //if(paramValue != null)
            //{
            //    String ParamValue = paramValue.ToString().ToLower();
            //    if

            //}
            
        }

        protected DataTable ExecuteProcedureDataTable(string procedureName, params (string paramName, dynamic paramValue, SqlDbType paramSqlDbType)[] parameters)
        {
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(procedureName, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    foreach ((string paramName, dynamic paramValue, SqlDbType paramSqlDbType) parameter in parameters)
                    {
                        SqlParameter param = command.Parameters.Add(parameter.paramName, parameter.paramSqlDbType);
                        param.IsNullable = true;
                        if (parameter.paramValue != null) param.Value = parameter.paramValue; else param.Value = DBNull.Value;
                    }

                    SqlDataReader dr = command.ExecuteReader();
                    DataTable dataTable = new DataTable(procedureName.Replace("dbo.", string.Empty));
                    dataTable.Load(dr);
                    return dataTable;
                }
            }
        }

        /// <summary>
        /// Execute Stored Procedure without output
        /// </summary>
        /// <param name="procedureName"></param>
        /// <param name="parameters"></param>
        public void ExecuteProcedure(string procedureName, params (string paramName, dynamic paramValue, SqlDbType paramSqlDbType)[] parameters)
        {
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(procedureName, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    foreach ((string paramName, dynamic paramValue, SqlDbType paramSqlDbType) parameter in parameters)
                    {
                        SqlParameter param = command.Parameters.Add(parameter.paramName, parameter.paramSqlDbType);
                        param.IsNullable = true;
                        if (parameter.paramValue != null) param.Value = parameter.paramValue; else param.Value = DBNull.Value;
                    }
                    command.ExecuteNonQuery();
                }
            }
        }

        /// <summary>
        /// Execute SQL Function
        /// </summary>
        /// <param name="functionName"></param>
        /// <param name="parameters"></param>
        /// <returns></returns>
        protected dynamic ExecuteScalarFunction(string functionName, params (string paramName, dynamic paramValue, SqlDbType paramSqlDbType)[] parameters)
        {
            dynamic returnValue = null;
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(functionName, connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    foreach ((string paramName, dynamic paramValue, SqlDbType paramSqlDbType) parameter in parameters)
                    {
                        SqlParameter param = command.Parameters.Add(parameter.paramName, parameter.paramSqlDbType);
                        param.IsNullable = true;
                        if (parameter.paramValue != null) param.Value = parameter.paramValue; else param.Value = DBNull.Value;
                    }
                    SqlParameter returnValueParam = new SqlParameter() { Direction = ParameterDirection.ReturnValue, ParameterName = "RetVal" };
                    command.Parameters.Add(returnValueParam);
                    command.ExecuteScalar();
                    returnValue = (dynamic)returnValueParam.Value;
                }
            }
            return returnValue;
        }
    }

}
