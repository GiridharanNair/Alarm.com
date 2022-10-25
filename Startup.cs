using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using BlazorFileSaver;
using Cardinal.Utils;
using Syncfusion.Blazor;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Returns.Models;
using ReturnsBlazor.Data;
using ReturnsBlazor.Services;

namespace ReturnsBlazor
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        // For more information on how to configure your application, visit https://go.microsoft.com/fwlink/?LinkID=398940
        public void ConfigureServices(IServiceCollection services)
        {
            //Platform
            services.AddRazorPages();
            services.AddControllers();
            services.AddServerSideBlazor().AddHubOptions((o) =>
            {
                o.MaximumReceiveMessageSize = int.MaxValue;
            });
            services.AddHttpContextAccessor();
            services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();

            //Authentication
            services.AddAuthentication(sharedOptions =>
            {
                sharedOptions.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
                sharedOptions.DefaultSignInScheme = CookieAuthenticationDefaults.AuthenticationScheme;
                sharedOptions.DefaultSignOutScheme = CookieAuthenticationDefaults.AuthenticationScheme;
                sharedOptions.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
            })
            .AddCookie()
            .AddOpenIdConnect(options =>
            {
                options.ClientId = Configuration["OAuth:ClientId"];
                options.ClientSecret = Configuration["OAuth:ClientSecret"];
                options.Authority = Configuration["OAuth:Authority"];
                options.CallbackPath = "/authorization-code/callback";
                options.ResponseType = OpenIdConnectResponseType.Code;
                options.SaveTokens = true;
                options.UseTokenLifetime = true;
                options.GetClaimsFromUserInfoEndpoint = true;
                options.Scope.Add("openid");
                options.Scope.Add("email");
                options.Scope.Add("profile");
                options.Scope.Add("offline_access");
                options.TokenValidationParameters.ValidateIssuer = false;
                options.TokenValidationParameters.NameClaimType = "email";
                options.Events = new OpenIdConnectEvents
                {
                    OnRemoteFailure = context => {
                        context.Response.Redirect("/account/unauthorized");
                        context.HandleResponse();
                        return Task.FromResult(0);
                    }
                };
            });

            //Application services
            services.AddScoped<RequestManager>();
            services.AddScoped<Services.EmailSenderService>();
            services.AddScoped<ReturnsDataContext>();
            services.AddScoped<AppsDataContext>();

            //3rd party services
            //Syncfusion.Licensing.SyncfusionLicenseProvider.RegisterLicense("MjcyNjM0QDMxMzgyZTMxMmUzMEJYNHhGTXhqazNLVVBvRXRsQkkrQUtjUXA3OXpMekNFb0VKVVFEQVZiTjg9");
            Syncfusion.Licensing.SyncfusionLicenseProvider.RegisterLicense("MzIyODk5QDMxMzgyZTMyMmUzMFNZaTNqSGdZbjB2K2l1dHVPUTUybE9rbWxOcDZzMThUT3pPcndDcmdPalU9");
            services.AddTelerikBlazor();
            services.AddBlazorFileSaver();
            services.AddSyncfusionBlazor();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseCookiePolicy();
            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();
            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
                endpoints.MapBlazorHub();
                endpoints.MapFallbackToPage("/_Host");
            });
        }
    }

}