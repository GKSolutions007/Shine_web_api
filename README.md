# Shine Web API — Architecture & Call Flow Reference

> **Purpose of this document:** A durable index of every layer, file, endpoint, and design decision in the project, written so that any future enhancement or bug fix can be traced end-to-end without reading every file from scratch.

---

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [Solution Structure](#2-solution-structure)
3. [Project Layout — SampWebApi](#3-project-layout--sampwebapi)
4. [Data Access Layer (DALHelper)](#4-data-access-layer-dalhelper)
5. [Business Layer (BuisnessLayer)](#5-business-layer-buinesslayer)
6. [Authentication & Authorization](#6-authentication--authorization)
7. [Request Pipeline & Configuration](#7-request-pipeline--configuration)
8. [API Endpoint Index](#8-api-endpoint-index)
9. [Models / DTOs](#9-models--dtos)
10. [Utility & Helper Classes](#10-utility--helper-classes)
11. [Complete Call Flow Walkthrough](#11-complete-call-flow-walkthrough)
12. [Key Design Patterns & Known Gotchas](#12-key-design-patterns--known-gotchas)
13. [Stored Procedure Naming Convention](#13-stored-procedure-naming-convention)
14. [Configuration Quick Reference](#14-configuration-quick-reference)
15. [Error Handling Strategy](#15-error-handling-strategy)

---

## 1. Technology Stack

| Dimension | Detail |
|-----------|--------|
| Framework | ASP.NET MVC 5 + ASP.NET Web API 2 |
| Target .NET | .NET Framework 4.8 |
| Hosting | IIS / IIS Express |
| Database | Microsoft SQL Server (stored-procedure-only access) |
| Auth | JWT (HMAC-SHA256) delivered via HTTP-only cookies |
| JSON | Newtonsoft.Json 13.0.3 |
| PDF | iTextSharp 5.5.13.4 + Spire.PDF 11.9.17 |
| Excel | ClosedXML 0.104.2 + ExcelDataReader 3.9.0 + NPOI 2.8.0 |
| Images | SixLabors.ImageSharp 2.1.3 |
| Barcodes | MessagingToolkit.QRCode + Zen.Barcode |
| Crypto | BouncyCastle.Cryptography 2.6.2 (e-invoice signing) |
| OWIN | Microsoft.Owin 4.2.2 (registered but inactive — see §12) |

---

## 2. Solution Structure

```
SampWebApi.sln
├── SampWebApi/           ← Main web application (all controllers, business logic, models)
├── Shinewebprint/        ← Class library: PDF merging utility (MergePDF.cs)
├── BuinessLayer/         ← Standalone class library (lightweight BL wrapper — not used at runtime by web)
└── DALHelper/            ← Standalone class library (lightweight DAL — not used at runtime by web)
```

> **Important:** `SampWebApi` contains its **own inlined copies** of both the DAL and business layer inside its subfolders `SampWebApi/DALHelper/` and `SampWebApi/BuisnessLayer/`. The standalone `BuinessLayer.dll` is referenced in the `.csproj` but the **web project's own inlined classes are what controllers instantiate**. When fixing bugs, always edit the files inside `SampWebApi/`.

---

## 3. Project Layout — SampWebApi

```
SampWebApi/
├── App_Start/
│   ├── WebApiConfig.cs         ← CORS, route registration, PdfEmbeddingHeaderHandler, SessionEnabledAttribute
│   ├── RouteConfig.cs          ← MVC route (Home/Index only)
│   └── BundleConfig.cs
├── BuisnessLayer/              ← Inlined business layer (used at runtime)
│   ├── clsBusinessLayer.cs     ← Facade over DAL + all utility methods
│   ├── clsEncryptDecrypt.cs    ← AES-256 encrypt/decrypt
│   └── TokenHelper.cs          ← JWT generation, refresh token repo (RefreshTokenRepo class lives here)
├── Controllers/                ← 42 API controllers (see §8)
├── DALHelper/                  ← Inlined data access layer (used at runtime)
│   ├── clsDAL.cs               ← All SQL execution + transaction management
│   ├── clsEncryptDecrypt.cs    ← AES-256 (duplicate of BuisnessLayer copy)
│   └── Connection.cs           ← Returns raw encrypted connection string from Web.config
├── Models/                     ← Plain C# POCOs (request/response DTOs)
├── Printing/                   ← PDF generation helpers (called from InvoiceController)
├── ReportExport/               ← Report export helpers
├── Barcode/                    ← Barcode generation
├── BarcodePrinting/            ← Barcode print helpers
├── Utility/
│   ├── CookieAuthorizeAttribute.cs  ← [CookieAuthorize] filter — per-request JWT validation
│   ├── JwtSettings.cs               ← Static class: JWT issuer, audience, signing key, expiry values
│   └── OAuthProvider.cs             ← Legacy OWIN OAuth — currently commented out / inactive
├── Areas/                      ← MVC Areas (if any)
├── Global.asax.cs              ← Application startup wiring
├── Startup.cs                  ← OWIN startup (registered but no-op; ConfigureOAuth is commented out)
└── Web.config                  ← All app configuration (see §14)
```

---

## 4. Data Access Layer (DALHelper)

**Files:** `SampWebApi/DALHelper/Connection.cs`, `clsDAL.cs`, `clsEncryptDecrypt.cs`

### 4.1 Connection Management

```
Web.config (encrypted blob)
  └─► Connection.GetConnectionString()       — returns raw encrypted string
        └─► clsDAL.Connectionstr()           — calls clsEncryptDecrypt.Decrypt() → plain connection string
              └─► new SqlConnection(...)     — used by every DAL method
```

Two connection strings exist:
- **`Connections`** — main application database (used by `clsDAL`)
- **`ShinecodeConnection`** — secondary database for Shinecodes export/sync features

### 4.2 clsDAL Method Reference

`clsDAL` holds two `SqlConnection` + two `SqlTransaction` instances to support dual-database transactions simultaneously.

| Method | Signature | Purpose |
|--------|-----------|---------|
| `dl_ExecuteSqlQuery` | `(string strquery) → DataTable` | Ad-hoc SQL query, opens a `using` connection |
| `dl_ExecuteParamSP` | `(string spName, params object[] params) → DataTable` | Execute stored proc, fresh `using` connection |
| `dl_ExecuteParamSPDataset` | `(string spName, params object[] params) → DataSet` | Same but returns multi-table `DataSet` |
| `dl_Transaction` | `(int Action)` | Main DB transaction: `1`=Begin, `2`=Commit, `3`=Rollback. Stores open connection as field. |
| `dl_ManageTrans` | `(string spName, params object[] obj) → DataTable` | Execute SP on the **open transaction** connection. Auto-rollbacks on exception. |
| `dl_Transaction_SC` | `(int Action)` | Same as `dl_Transaction` but for `ShinecodeConnection` |
| `dl_ManageTrans_SC` | `(string spName, params object[] obj) → DataTable` | Execute SP on open Shinecode transaction |

### 4.3 Parameter Binding

All stored procedures use **`SqlCommandBuilder.DeriveParameters`** — the DAL introspects SQL Server at runtime to get parameter metadata, then assigns values **by position** (`cmd.Parameters[i + 1].Value = parameters[i]`).

- **Implication for bug fixes:** If a stored procedure's parameter order changes on the SQL Server side, the C# call will silently pass wrong values. Always keep SP parameter order in sync with the caller's `params object[]` array.
- **Table-Valued Parameters (TVPs):** `dl_ManageTrans` strips the schema prefix from `TypeName` (e.g., `dbo.TypeName` → `TypeName`) before assigning a `DataTable`.

### 4.4 clsEncryptDecrypt

AES-256 encryption with a **hardcoded key** `"MAKV2SPBNI99212"` and hardcoded salt. Used to decrypt connection strings and encrypt/decrypt passwords. The identical class exists in both `DALHelper/` and `BuisnessLayer/`.

---

## 5. Business Layer (BuisnessLayer)

**Files:** `SampWebApi/BuisnessLayer/clsBusinessLayer.cs`, `clsEncryptDecrypt.cs`, `TokenHelper.cs`

### 5.1 clsBusinessLayer

Instantiates `clsDAL ObjDL = new clsDAL()` and acts as the single facade that all controllers use.

**DAL pass-through methods:**

| BL Method | Delegates to DAL |
|-----------|-----------------|
| `BL_ExecuteParamSP(spName, params)` | `ObjDL.dl_ExecuteParamSP` |
| `BL_ExecuteSqlQuery(query)` | `ObjDL.dl_ExecuteSqlQuery` |
| `BL_ExecuteParamSPDataset(spName, params)` | `ObjDL.dl_ExecuteParamSPDataset` |
| `bl_Transaction(action)` | `ObjDL.dl_Transaction` |
| `bl_ManageTrans(spName, params)` | `ObjDL.dl_ManageTrans` |
| `bl_Transaction_SC(action)` | `ObjDL.dl_Transaction_SC` |
| `bl_ManageTrans_SC(spName, params)` | `ObjDL.dl_ManageTrans_SC` |
| `ExecuteParamSP_SC(spName, params)` | Opens a fresh `ShinecodeConnection` directly (no transaction) |
| `ExecuteParamSPDataSet_SC(spName, params)` | Same, returns `DataSet` |

**Application utility methods:**

| Method | Purpose |
|--------|---------|
| `BL_DBName()` | `SELECT DB_NAME()` — used in error logging |
| `BL_AppConfigValuebyID(int AppID)` | Queries `tblAppConfig` by AppId |
| `BL_ShineCode(int MasterType, int ID)` | Calls `uspGetShineCode` |
| `ReturnGrossorMRPTaxAmt(...)` | Tax amount calculation via `uspGetTaxCumulative` |
| `ConvertListToDataTable<T>(List<T>)` | Reflection-based list → DataTable (for TVP parameters) |
| `listConvertToDataTable<T>(...)` | Alternate list → DataTable variant |
| `BL_AddCollectionData(header, detail, mop)` | Builds typed DataTable schemas for collection transactions |
| `SendEmail(subject, body, toMailID, ...)` | SMTP via Gmail smtp.gmail.com:587/TLS |
| `BL_WriteErrorMsginLog(module, action, msg)` | Writes JSON error entry to daily log file |
| `BL_LogFileWrite(...)` | Low-level file write for log entries |

**Validation helpers** (all regex-based, return `bool`):
`BL_PANValidation`, `BL_isValidGSTIN`, `BL_AadhaarValidate`, `BL_MobileNumberValidate`, `BL_FSSAIValidate`, `BL_Email`, `BL_Dateonly`, `BL_NumericWithDecimal`, `BL_AlphaNumericSpl`

---

## 6. Authentication & Authorization

### 6.1 Login Flow (`GET api/login/get`)

```
Client sends: username, password, deviceID query params
  │
  ▼
LoginController.GetLoginData()
  │  ► uspManageUsers (Mode=6) — validates AES-encrypted password
  │  ► uspValidateDevice      — checks device registration status
  │     ├─ New device        → send OTP email, return Mode=2 (stop here)
  │     ├─ Inactive device   → send device OTP, return Mode=2 (stop here)
  │     ├─ Expired license   → return Mode=4 (stop here)
  │     └─ Concurrent login  → return Mode=5 (stop here)
  │
  ▼  (successful validation)
TokenHelper.GenerateToken(userId, deviceId)
  │  ► Creates JWT (HMAC-SHA256, expires AuthTokenExpiresInMins=60 min)
  │  ► Claims: ClaimTypes.Name, sub, jti
  │  ► Sets HttpOnly Secure cookie "AuthToken" (expires RefreshTokenExpiresInDays=2 days)
  │  ► Sets HttpOnly Secure cookie "DeviceID"
  │
  ▼
TokenHelper.GenerateRefreshToken(userId, authToken, deviceId)
  ► Generates 64-byte random refresh token
  ► Saves to DB via uspInsertRefreshToken (stores SessionId, AuthToken, expiry)
  ► Sets HttpOnly Secure cookie "RefreshToken"
  ► Sets HttpOnly Secure cookie "DeviceID"
  │
  ▼
Controller returns user data (menus, theme, filter dates, etc.)
```

### 6.2 Per-Request Authorization (`[CookieAuthorize]`)

Applied as a class-level attribute on most controllers. Override of `AuthorizeAttribute.IsAuthorized`:

```
Request arrives with cookies: AuthToken, DeviceID
  │
  ▼
CookieAuthorizeAttribute.IsAuthorized()
  │  1. Reads "AuthToken" cookie
  │  2. RefreshTokenRepo.GetAuthToken(token) → uspGetRefreshToken (TokenType=2)
  │     ├─ Token not in DB, expired, or IsRevoked=false → return false (401)
  │  3. RefreshTokenRepo.ValidateTrustDevice(deviceId) → uspValidateDevice (Mode=5)
  │     ├─ Device not trusted → return false (401)
  │  4. JwtSecurityTokenHandler.ValidateToken(token, validationParams)
  │     ├─ Validates signature (JwtSettings.SecretKey), issuer, audience, lifetime
  │     └─ On failure → return false (401)
  │  5. Sets HttpContext.Current.User = JWT claims principal
  └─► return true → controller action executes
```

### 6.3 Token Refresh (`POST api/token/refresh`)

```
Client sends cookies: RefreshToken, AuthToken, DeviceID
  │
  ▼
TokenController
  ► Validate DeviceID via uspValidateDevice
  ► Get refresh token record via uspGetRefreshToken (TokenType=1)
  ► Check not expired, not revoked
  ► Revoke old auth token via uspUpdateRefreshToken (TokenType=2)
  ► Revoke old refresh token via uspUpdateRefreshToken (TokenType=1)
  ► Generate new JWT + new refresh token (same flow as login)
```

### 6.4 JWT Settings

| Setting | Source | Value |
|---------|--------|-------|
| `SecretKey` | **Hardcoded** in `JwtSettings.cs` | `"dbCed6XiHRSd7RoF5YAjXLD72pB1IkXlbyKHhtzS/DQ="` |
| `Issuer` | `Web.config` appSettings `ValidIssuer` | `https://localhost:44396/` |
| `Audience` | `Web.config` appSettings `ValidAudience` | `https://localhost:44326/` |
| `AuthTokenExpiresInMins` | `Web.config` appSettings | `60` |
| `RefreshTokenExpiresInDays` | `Web.config` appSettings | `2` |

> ⚠️ `OAuthProvider.cs` / `Startup.cs` reference a **different commented-out key** `"yPqB3dmFXNfJg6X1W/JzNX4A2Sc6sZ7Q7+p2lYxPrCY="`. If OWIN OAuth is ever re-enabled, the key must be unified.

---

## 7. Request Pipeline & Configuration

### 7.1 Startup Sequence

```
IIS → Global.asax (Application_Start)
  ├─ WebApiConfig.Register(config)
  │    ├─ EnableCors (AllowedOrigins from appSettings, SupportsCredentials=true)
  │    ├─ config.MessageHandlers.Add(PdfEmbeddingHeaderHandler)
  │    ├─ config.MapHttpAttributeRoutes()  ← attribute routing (used by all controllers)
  │    ├─ config.Routes.MapHttpRoute("DefaultApi", "api/{controller}/{id}")
  │    └─ config.Filters.Add(SessionEnabledAttribute)
  ├─ RouteConfig.RegisterRoutes(routes)   ← MVC route for Home/Index
  └─ BundleConfig.RegisterBundles(bundles)
```

### 7.2 Key Message Handlers & Filters

| Component | Type | Effect |
|-----------|------|--------|
| `PdfEmbeddingHeaderHandler` | DelegatingHandler | Adds `Content-Security-Policy: frame-ancestors <origin>` and `Vary: Origin` to PDF responses |
| `SessionEnabledAttribute` | ActionFilterAttribute (global) | Ensures `HttpContext.Current.Session` is initialized on every request |
| `CookieAuthorizeAttribute` | AuthorizeAttribute | Applied per-controller; validates JWT + device cookies |

### 7.3 CORS

Single allowed origin read from `appSettings["AllowedOrigins"]`. `SupportsCredentials = true` is required for cookie-based auth to work cross-origin. **Both the origin in `Web.config` and the Blazor/frontend app's URL must match exactly.**

---

## 8. API Endpoint Index

All endpoints use attribute routing (`[Route("api/...")]`). Unless noted, all listed controllers carry `[CookieAuthorize]` at the class level.

### Authentication

| Controller | Method | Route | Auth | Notes |
|------------|--------|-------|------|-------|
| `LoginController` | GET | `api/login/get` | None | Login; validates credentials + device, issues JWT cookies |
| `LoginController` | POST | `api/signup/save` | None | Create/update user (`uspManageUsers`), password AES-encrypted |
| `LoginController` | GET | `api/signup/get` | [CookieAuthorize] | Get user(s) Mode 3/4 or salesmen list Mode 7 |
| `LoginController` | GET | `api/signup/sendaam` | None | Send account activation email |
| `LoginController` | POST | `api/signup/updateuser` | None | Update user profile + image upload (ImageSharp compress) |
| `TokenController` | POST | `api/token/refresh` | None | Validate refresh token, issue new JWT pair |
| `SystemApprovalController` | GET/POST | `api/MobileDeviceApproval/get`, `/save` | None | Mobile device approval |
| `SystemApprovalController` | GET/POST | `api/DeviceApproval/get`, `/save` | None | Web device approval |
| `MobileDeviceVerifyController` | GET | `api/mobiledeviceverify/verify` | None | Verify mobile device OTP |
| `MobileDeviceVerifyController` | GET | `api/mobiledevicelogin/loginverify` | None | Mobile login verification |

### Masters & Configuration

| Controller | Routes (all [CookieAuthorize]) |
|------------|-------------------------------|
| `AllMastersController` | `api/singlemaster/get`, `api/singlemaster/save`, `api/singlemaster/getactivedata` |
| | `api/taxmaster/get`, `api/taxmaster/save` |
| | `api/taxcompgift/get`, `api/taxcompgift/save` |
| | `api/bankaccount/get`, `api/bankaccount/save` |
| | `api/financialaccount/get`, `api/financialaccount/getalldata`, `api/financialaccount/save` |
| | `api/financialaccountgroup/get`, `api/financialaccountgroup/getalldata`, `api/financialaccountgroup/save` |
| | `api/faopening/get`, `api/faopening/save` |
| | `api/chequebook/get`, `api/chequebook/save` |
| | `api/salesman/get`, `api/salesman/save` |
| | `api/branchoffice/get`, `api/branchoffice/save` |
| | `api/vehicle/get`, `api/vehicle/save` |
| | `api/service/get`, `api/service/save` |
| | `api/colorsettings/get`, `api/colorsettings/save` |
| | `api/applicationconfig/get`, `api/applicationconfig/save` |
| | `api/menuorder/get`, `api/menuorder/save` |
| | `api/documentseries/get`, `api/documentseries/save` |
| | `api/companydetails/get`, `api/companydetails/save` |
| | `api/discountscheme/get`, `api/discountscheme/getalldata`, `api/discountscheme/getfilterdata`, `api/discountscheme/save` |
| | `api/verifyapppassword/verify` |
| | `api/transactionprint/get` |
| | `api/oneview/getparty`, `api/oneview/getdata` |
| | `api/updateproductlocation/get`, `api/updateproductlocation/save` |
| | `api/homescreendraft/get`, `api/homescreen/brandsummary` |
| | `api/getfilterdates/get`, `api/quicaccessdocument/validate` |

### Party & Product Masters

| Controller | Routes |
|------------|--------|
| `CustomerVendorProductController` | `api/customermaster/get`, `api/customermaster/save` |
| | `api/customermaster/validatestatutory` |
| | `api/customermaster/CustomerLocation`, `api/customermaster/CustomerLocationVerificationSave` |
| | `api/customermaster/CustomerLocationImage` |
| | `api/vendormaster/get`, `api/vendormaster/getalldata`, `api/vendormaster/save` |
| | `api/productmaster/get`, `api/productmaster/getalldata`, `api/productmaster/save` |
| | `api/productpricechange/get`, `api/productpricechange/save` |

### Sales Transactions

| Controller | Method | Route | Notes |
|------------|--------|-------|-------|
| `InvoiceController` | GET | `api/invoice/get` | Load invoice data by mode/ID |
| | GET | `api/invoice/variantdata` | Product variant info |
| | GET | `api/invoice/cancelotdraft` | Cancel order-taken draft |
| | GET | `api/invoice/getproductlist` | Product search/list |
| | GET | `api/invoice/getcustomerlist` | Customer search |
| | GET | `api/invoice/discountschemeinfo` | Discount scheme details |
| | GET | `api/invoice/getfilterdata` | Filter/list invoices |
| | GET | `api/invoice/validatecreditlimit` | Check credit limit |
| | GET | `api/invoice/invoicecollectiondata` | Collection info for invoice |
| | POST | `api/invoice/verifycreditlimit` | Verify credit |
| | POST | `api/invoice/save` | **Save invoice** (transactional, TVPs) |
| | GET | `api/invoice/PDFGenerate` | Generate PDF |
| | GET | `api/invoice/MailGenerate` | Send invoice email |
| | GET | `api/invoice/AutomaticMailGenerate` | Bulk auto email |
| | GET | `api/invoice/WhatsappGenerate` | WhatsApp share |
| | GET | `api/invoice/downloadprint` | Download printout |
| | GET | `api/transactionprint/generateprint` | Generic transaction print |
| `QuotationController` | GET | `api/quotation/get`, `api/quotation/getfilterdata`, `api/quotation/pricetypechange`, `api/quotation/getvariantdata` | |
| | POST | `api/quotation/save` | |
| `SalesReturnController` | GET | `api/salesreturn/get`, `api/salesreturn/getvariantdata`, `api/salesreturn/productnewbatch`, `api/salesreturn/getfilterdata`, `api/salesreturn/cancelsrdraft` | |
| | POST | `api/salesreturn/getexistssrbatch`, `api/salesreturn/save` | |
| `AssignInvoicesController` | GET | `api/assigninvoices/getdata` | |
| | POST | `api/assigninvoices/save` | |

### Purchase Transactions

| Controller | Routes |
|------------|--------|
| `PurchaseBillController` | `api/purchasebill/get`, `api/purchasebill/invoicedata`, `api/purchasebill/getfilterdata` (GET), `api/purchasebill/save` (POST) |
| `PurchaseReturnController` | `api/purchasereturn/get`, `api/purchasereturn/variantdata`, `api/purchasereturn/getfilterdata`, `api/purchasereturn/manufproducts`, `api/purchasereturn/pricetypechange` (GET), `api/purchasereturn/save` (POST) |
| `PurchaseOrderController` | `api/purchaseorder/get`, `api/purchaseorder/productqtybatch`, `api/purchaseorder/getfilterdata`, `api/purchaseorder/manufitems` (GET), `api/purchaseorder/save` (POST) |
| `AutomaticIndentController` | `api/automaticindent/get`, `api/automaticindent/getbranchqty`, `api/automaticindent/getfilterdata` (GET), `api/automaticindent/save` (POST) |

### Collection & Payment

| Controller | Routes |
|------------|--------|
| `CollectionPaymentController` | `api/collectionpayment/get`, `api/collectionpayment/getosdocs`, `api/collectionpayment/variant`, `api/collectionpayment/webcollosdocs`, `api/collectionpayment/validatewebcollosdocs`, `api/collectionpayment/getfilterdata` (GET), `api/collectionpayment/save` (POST) |
| `BulkCollectionController` | `api/bulkcollection/filterdata`, `api/bulkcollection/documentdata` (GET), `api/bulkcollection/save` (POST) |

### Accounting / Finance

| Controller | Route Groups |
|------------|-------------|
| `AccountsController` | `api/creditdebitnote/get`, `getfilterdata`, `save` |
| | `api/prvoucher/get`, `getfilterdata`, `save` |
| | `api/contra/get`, `getfilterdata`, `save` |
| | `api/journalentry/get`, `getfilterdata`, `save` |
| | `api/othercollectionpayment/get`, `getfilterdata`, `save` |
| | `api/dailycashexpenses/get`, `save` |
| | `api/chequedeposit/get`, `cancel`, `getfilterdata`, `save` |
| | `api/bouncerealisation/get`, `getfilterdata`, `save`, `cancel` |
| | `api/brsdata/get`, `save` |
| | `api/gstreconsiliation/getgstrecon`, `savegstrecon` |
| | `api/preferredlanguage/getpreferredlanguage`, `savepreferredlanguage` |
| `FinancialReportsController` | `api/FinancialReportpermissions`, `api/financialreportparameters/get` (GET), `api/financialreportgenerate/get` (POST), `api/financialrepcolumnsettings/getcolumnsettings` (GET), `api/financialrepcolumnsettings/Savecolumnsettings` (POST) |

### Delivery & Logistics

| Controller | Routes |
|------------|--------|
| `DeliveryController` | `api/delivery/get`, `api/delivery/filterdata` (GET), `api/delivery/invoicedata`, `api/delivery/invoiceproducts`, `api/delivery/save` (POST) |
| `VanLoadingSlipController` | `api/vanloadslip/getdata`, `api/vanloadslip/filterdata`, `api/vanloadslip/vlsdocumentdata`, `api/vanloadslip/productdetails`, `api/vanloadslip/productbatch` (GET), `api/vanloadslip/save` (POST) |
| `VanLoadingSlipReturnController` | `api/vlsreturn/initialdata`, `api/vlsreturn/products` (GET), `api/vlsreturn/save` (POST) |

### Mobile / Daily Activity

| Controller | Routes |
|------------|--------|
| `DailyActivityController` | `api/dailyactivity/getdata`, `api/dailyactivity/itemfilter` (GET), `api/dailyactivity/save` (POST) |
| | `api/mobilecollection/getdata` (GET), `api/mobilecollection/save` (POST) |
| | `api/webcollection/getdata`, `api/webcollection/filterdata` (GET), `api/webcollection/cancel` (POST) |
| | `api/bulkordertaken/filterdata`, `api/bulkordertaken/filterdocuments`, `api/bulkordertaken/otdata` (GET), `api/bulkordertaken/cancel` (POST) |

### Inventory

| Controller | Routes |
|------------|--------|
| `InventoryController` | `api/inventoryadjustment/get`, `api/inventoryadjustment/getfilterdata`, `api/inventoryadjustment/producthistory` (GET), `api/inventoryadjustment/save` (POST) |
| | `api/inventoryconvertion/get`, `api/inventoryconvertion/getfilterdata` (GET), `api/inventoryconvertion/save` (POST) |
| `StockDestructionController` | `api/stockdestruction/get`, `api/stockdestruction/getfilterdata` (GET), `api/stockdestruction/save` (POST) |

### GST / e-Invoice

| Controller | Method | Route |
|------------|--------|-------|
| `EInvoiceEwayController` | GET | `api/einvoiceeway/get` |
| | POST | `api/einvoiceeway/getjson` |
| | GET | `api/downloadjsondata` |
| | POST | `api/einvoiceeway/uploadjsonfile` |
| | POST | `api/einvoiceeway/updateewayinfo` |

### Reports

| Controller | Routes |
|------------|--------|
| `ReportController` | `api/Reportpermissions`, `api/reportparameters/get` (GET) |
| | `api/reportgenerate/get` (POST) |
| | `api/reportexport/export` (POST), `api/gstreportexport/gstexport` (GET) |
| | `api/reportscript/get` (GET) |
| | `api/reportcolumnsettings/getRepColumnSettings` (GET), `api/reportcolumnsettings/SaveRepColumnSettings` (POST) |
| | `api/commonfilter/commonfilterdata` (POST) |
| | `api/columnsettings/getcolumnsettings` (GET), `api/columnsettings/Savecolumnsettings`, `api/columnsettings/Savetransactioncolumnsettings` (POST), `api/columnsettings/updatecolumnwidth` (GET) |
| `PartyProductAnalticReportController` | `api/partyanalticalreport/getparty`, `getdocuments` (GET) |
| | `api/productanalticalreport/getproduct`, `getdocuments` (GET) |
| | `api/invoiceanalticalreport/getinvoices`, `getdocuments` (GET) |
| | `api/customeros/initiatedata`, `generatedata` (GET) |
| | `api/monthwisesalesanaltic/filterdata` (GET), `api/monthwisesalesanaltic/generatedata` (POST) |

### Tools & Configuration

| Controller | Routes |
|------------|--------|
| `ToolsController` | `api/printprofileconfig/get`, `api/printprofileconfig/getprofile` (GET), `api/printprofileconfig/save` (POST) |
| | `api/transactionvariant/gettrans`, `api/maprole/getroles`, `api/maprole/gettreedata` (GET), `api/maprole/savemaprole` (POST) |
| | `api/BranchMapping/get`, `api/BranchMapping/getByRole` (GET), `api/BranchMapping/save` (POST) |
| | `api/mfrmap/getusers`, `api/mfrmap/usersmfrdata` (GET), `api/mfrmap/save` (POST) |
| `PrintCustomizeController` | `api/printcustomize/getcontrols`, `transactioncontrols`, `initialDatas`, `renameprofile`, `deleteprofile`, `profilescript` (GET), `api/printcustomize/savecontrols` (POST) |
| `BarcoderPrintController` | `api/barcodeprint/filterdata`, `Productdata`, `bpdocumentdata`, `productbatch`, `print`, `downloadprint` (GET), `api/barcodeprint/save` (POST) |
| `BarcodrprofileconfigController` | `api/barcodeprofiles/initialDatas`, `remove` (GET), `api/barcode/uploadfile`, `api/barcodeprofiles/saveprofiles` (POST) |
| `ColumnConfigController` | Column configuration routes |
| `CustomizebillprintController` | Bill print customization routes |
| `CustomizeReportsController` | Report customization routes |
| `ModifyhistoryController` | Modification history routes |

### Data Sync & Import/Export

| Controller | Routes |
|------------|--------|
| `ShinecodesController` | `api/shinecode/masterdata` ([CookieAuthorize]), `api/shinecode/template`, `progress`, `download` (GET), `api/shinecode/startexport`, `startimport` (POST) |
| `MasterSyncController` | `api/mastersync/synctables` (GET), `api/mastersync/syncdata` (POST) |
| `ImportexportController` | `api/uploadimportfile` (POST), `api/uploadtransactionimportfile` (POST), `api/generatetemplate`, `api/exporttemplate`, `api/downloaderrordata` (GET) |
| `TransactionImportController` | Transaction import routes |
| `UploadFilesController` | `api/backupfile`, `api/downloadbakfile`, `api/deletemyuploadfile`, `api/listbackupfiles` (GET), `api/olduploadfile/upload` (POST) |

### Shared / Common

| Controller | Routes |
|------------|--------|
| `CommonController` | `api/documentseries/docid`, `api/mrpontax`, `api/taxdetails`, `api/validatedocument`, `api/validatedraftdocument`, `api/validateinvoicetransferdocument`, `api/logfiles`, `api/logfiledata`, `api/masterlist` (all GET) |
| `HomeController` | MVC `Home/Index` — browser landing page only |

---

## 9. Models / DTOs

All models are in `SampWebApi/Models/` — plain C# POCOs, no validation attributes.

| File | Key Classes | Used By |
|------|-------------|---------|
| `SalesModel.cs` | `SalesModel`, `SalesDetail`, `PaymentmodeInfo`, `AssignInvoiceHeader`, `AssignInvoiceDetails`, `DailyActivity`, `DailyActivityDetails` | InvoiceController, QuotationController, SalesReturnController, AssignInvoicesController, DailyActivityController |
| `PurchaseModel.cs` | `PurchaseModel`, `PurchaseDetail`, `PurchaseBatchInfo` | PurchaseBillController, PurchaseReturnController, PurchaseOrderController, InventoryController |
| `CustomerVendorModel.cs` | `CustomerVendorModel`, `ProductModel` | CustomerVendorProductController |
| `AccouuntsModel.cs` | `AccouuntsModel`, `JournalEntry`, `OtherCollPayPMDetails`, `EInvoiceEwayModel`, `GstReconModel` | AccountsController, EInvoiceEwayController |
| `CollectionPaymentModel.cs` | `CollectionPaymentModel` | CollectionPaymentController, BulkCollectionController |
| `DeliveryModel.cs` | `DeliveryModel` | DeliveryController |
| `PrintCustomizeModel.cs` | `PrintCustomizeModel` | PrintCustomizeController |
| `SingleMasterModel.cs` | `SingleMasterModel`, `Users`, `BankAccount`, `FinancialAccount`, `Salesman`, `Tax`, `Chequebook`, `CompanyDeatils`, `ApplicationConfig`, `ReportParameters`, `ReportFilters`, `SaveMessage` | AllMastersController, LoginController, ReportController, CommonController |
| `RefreshToken.cs` | `RefreshToken` | TokenHelper / RefreshTokenRepo |
| `SampleModel.cs` | Various sample/utility models | Common utility use |

### SaveMessage — Standard Response Envelope

Most POST endpoints return `List<SaveMessage>`:
```csharp
class SaveMessage {
    string ID;      // New record ID on success; "0" on error
    string MsgID;   // "0" = success, "1" = error
    string Message; // "Saved Successfully" or error text from SP
}
```

---

## 10. Utility & Helper Classes

| File | Class | Purpose |
|------|-------|---------|
| `Utility/CookieAuthorizeAttribute.cs` | `CookieAuthorizeAttribute` | Per-request auth gate (see §6.2) |
| `Utility/JwtSettings.cs` | `JwtSettings` | Static holder for JWT config values |
| `BuisnessLayer/TokenHelper.cs` | `TokenHelper` | Static: `GenerateToken`, `GenerateRefreshToken` |
| `BuisnessLayer/TokenHelper.cs` | `RefreshTokenRepo` | DB repo: save/get/revoke tokens, validate device |
| `Utility/OAuthProvider.cs` | `CookieOAuthProvider` | Legacy OWIN OAuth — **not active** |
| `App_Start/WebApiConfig.cs` | `PdfEmbeddingHeaderHandler` | Adds CSP headers to PDF responses |
| `App_Start/WebApiConfig.cs` | `SessionEnabledAttribute` | Forces ASP.NET Session per request |
| `DALHelper/clsEncryptDecrypt.cs` | `clsEncryptDecrypt` | AES-256 encrypt/decrypt (hardcoded key) |
| `BuisnessLayer/clsEncryptDecrypt.cs` | `clsEncryptDecrypt` | Identical copy in BuisnessLayer namespace |
| `Printing/` | Various | PDF generation (called by InvoiceController) |
| `Shinewebprint/MergePDF.cs` | `MergePDF` | PDF merging across multiple print outputs |

---

## 11. Complete Call Flow Walkthrough

### 11.1 Transactional Write — `POST api/invoice/save`

```
① HTTP POST api/invoice/save
   Body: SalesModel JSON (header + detail lines + payment modes)

② IIS → ASP.NET Web API routing
   Matches InvoiceController.Save(SalesModel listTrans)

③ CookieAuthorizeAttribute.IsAuthorized()  [class-level filter]
   ├─ Read "AuthToken" cookie
   ├─ uspGetRefreshToken (TokenType=2) — validate token in DB
   ├─ uspValidateDevice (Mode=5) — validate "DeviceID" cookie
   └─ JwtSecurityTokenHandler.ValidateToken — check signature + lifetime
   → Sets HttpContext.Current.User; proceeds to action

④ InvoiceController.Save(listTrans)
   ├─ bl = new clsBusinessLayer()  [instance created in constructor]
   ├─ bl.listConvertToDataTable<SalesDetail>(listTrans.Details)
   │   → Reflection maps each property to DataTable column
   ├─ bl.bl_Transaction(1)
   │   → clsDAL.dl_Transaction(1)
   │   → aSqlconnection.Open() + aSqlconnection.BeginTransaction()
   │
   ├─ bl.bl_ManageTrans("uspSaveSalesInvoiceHeader", mode, custId, date, ...)
   │   → clsDAL.dl_ManageTrans(sp, params)
   │   → SqlCommandBuilder.DeriveParameters(cmd)  [runtime param introspection]
   │   → Assigns params positionally
   │   → SqlDataAdapter.Fill(dt)  [executes SP within transaction]
   │   → Returns DataTable with new document ID
   │
   ├─ bl.bl_ManageTrans("uspSaveSalesInvoiceDetail", docId, dtDetails)
   │   → Same as above; dtDetails is a TVP (SqlDbType.Structured)
   │   → Schema prefix stripped from TypeName before assignment
   │
   ├─ bl.bl_ManageTrans("uspSaveSalesPaymentMode", ...)
   │   → Payment mode detail saved
   │
   └─ bl.bl_Transaction(2)
       → aSqlTransaction.Commit()
       → aSqlconnection.Close()

⑤ Controller builds response
   ├─ DDT.Columns.Count == 1 → success path
   │   list.Add(new SaveMessage { ID=newDocId, MsgID="0", Message="Saved Successfully" })
   └─ Otherwise → error path
       list.Add(new SaveMessage { ID="0", MsgID="1", Message=errorText })

⑥ return Ok(list)
   → Newtonsoft.Json serializes List<SaveMessage> to JSON
   → HTTP 200 response

⑦ Exception path (any step above throws):
   └─ dl_ManageTrans auto-calls aSqlTransaction.Rollback()
   └─ Controller catch: bl.BL_WriteErrorMsginLog("Invoice","invoice/save", ex.Message)
   └─ return Ok()  ← HTTP 200, empty body — client must handle null response
```

### 11.2 Read-Only Query — `GET api/invoice/get`

```
① GET api/invoice/get?Mode=3&ID=12345

② CookieAuthorizeAttribute — same as above

③ InvoiceController.GetInvoice(string Mode, string ID)
   └─ bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, ID)
       └─ clsDAL.dl_ExecuteParamSP(spName, params)
           ├─ using (new SqlConnection(Connectionstr()))  ← fresh connection, no transaction
           ├─ SqlCommandBuilder.DeriveParameters(cmd)
           ├─ Positional param assignment
           └─ SqlDataAdapter.Fill(dt) → returns DataTable

④ Controller maps DataTable rows → typed List<SalesModel>
   └─ return Ok(list)  → JSON response
```

### 11.3 Mode-Based Dispatch Pattern

Many controllers/SPs use a `Mode` integer to multiplex operations:

| Mode | Typical Meaning |
|------|----------------|
| 1 | Insert (new record) |
| 2 | Update (existing record) |
| 3 | Get by ID |
| 4 | Get all / list |
| 5 | Delete / cancel |
| 6 | Login validation |
| 7 | Special list (e.g., salesmen) |

The actual mode values are SP-specific — always check the SP on the SQL Server side to confirm what each mode does.

---

## 12. Key Design Patterns & Known Gotchas

### ✅ Patterns in Use

- **SP-only data access** — zero inline SQL in controllers (except a few ad-hoc queries in LoginController; these bypass `clsDAL` and open their own raw `SqlConnection`).
- **AES-encrypted connection strings** — all `Web.config` connection strings are encrypted blobs; decrypted at runtime via `clsEncryptDecrypt.Decrypt()`.
- **HTTP-only cookie auth** — JWT is never exposed to JavaScript; all auth state lives in `HttpOnly Secure` cookies.
- **DataTable as universal return type** — all DAL methods return `DataTable` or `DataSet`; controllers map rows manually to typed models.

### ⚠️ Gotchas to Watch

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| 1 | **Positional SP params** | `clsDAL.dl_ExecuteParamSP` / `dl_ManageTrans` | Adding/reordering an SP parameter on SQL Server will silently corrupt data if the C# call array isn't updated simultaneously |
| 2 | **JWT secret — now configurable** | `Utility/JwtSettings.cs` + `Web.config` `JwtSecretKey` | ✅ Fixed: reads from encrypted `appSettings["JwtSecretKey"]`; falls back to hardcoded value until `Web.config` is updated |
| 3 | **No HTTP error codes** | All controller `catch` blocks | Exceptions return HTTP 200 with empty body — clients must handle null/empty response as error |
| 4 | **Duplicate DAL/BL code** | Standalone projects vs. inlined copies | Changes must be made in `SampWebApi/DALHelper/` and `SampWebApi/BuisnessLayer/` — the standalone project files are **not** what runs |
| 5 | **LoginController bypasses clsDAL** | `LoginController.cs` Mode 3/4 | Opens its own raw `SqlConnection` directly; uses lazy-decrypted `connectionString` property |
| 6 | **Hardcoded AES key** | Both `clsEncryptDecrypt.cs` copies | Key `"MAKV2SPBNI99212"` is in source code; changing it requires re-encrypting all connection strings |
| 7 | **`IsRevoked` logic** | `CookieAuthorizeAttribute.cs` | ✅ Fixed: condition corrected to `AuthTokenValidate.IsRevoked` (true = revoked/ended session) |
| 8 | **Query timeout** | All `dl_ExecuteParamSP` / `dl_ManageTrans` calls | ✅ Fixed: reads `QueryTimeoutSeconds` from `appSettings` (default 120s); was 0 (infinite) |
| 9 | **`SampWebApi.csproj` references standalone BuinessLayer.dll** | `.csproj` HintPath | The DLL is .NET 8 / netstandard; binding works but mixing runtimes could cause subtle issues |

---

## 13. Stored Procedure Naming Convention

| Prefix | Purpose | Examples |
|--------|---------|---------|
| `uspManageUsers` | User CRUD + login | Login (Mode=6), signup (Mode=1/2), get user (Mode=3/4) |
| `uspGetRefreshToken` | Auth token retrieval | TokenType=1 (refresh), TokenType=2 (auth) |
| `uspInsertRefreshToken` | Save new refresh token | — |
| `uspUpdateRefreshToken` | Revoke token | TokenType=1 or 2 |
| `uspValidateDevice` | Device trust check | Mode=5 (validate), other modes for OTP flows |
| `uspSaveSalesInvoice*` | Invoice save (header/detail) | Called within transaction |
| `uspGetSetInvoiceData` | Invoice read (get/list) | Mode-driven |
| `uspGetTaxCumulative` | Tax calculation | — |
| `uspGetShineCode` | Shine product code lookup | — |
| `uspManageTrans*` | Generic transaction SPs | Pattern common across modules |

---

## 14. Configuration Quick Reference

**`Web.config` key settings:**

```xml
<!-- Connection Strings (all AES-encrypted) -->
<add name="Connections" connectionString="[encrypted]" />        <!-- main DB -->
<add name="ShinecodeConnection" connectionString="[encrypted]" /> <!-- secondary DB -->

<!-- JWT -->
<add key="ValidIssuer"             value="https://localhost:44396/" />
<add key="ValidAudience"           value="https://localhost:44326/" />
<add key="AuthTokenExpiresInMins"  value="60" />
<add key="RefreshTokenExpiresInDays" value="2" />

<!-- CORS -->
<add key="AllowedOrigins" value="https://localhost:44326" />

<!-- SMTP (Gmail) -->
<add key="email"    value="shineasst@gmail.com" />
<add key="smtphost" value="smtp.gmail.com" />
<add key="passkey"  value="[AES-encrypted Gmail app password]" />

<!-- App -->
<add key="SupportFilePath" value="D:\\HOST\\NewWebShineSupport\\" />  <!-- log file root -->
<add key="MasterSyncDB"    value="WSHINE_DEV001_APR2024" />

<!-- Request size: 2 GB -->
<httpRuntime maxRequestLength="2097152" targetFramework="4.8" />
```

**To add a new environment / switch database:**
1. Encrypt the new connection string using `clsEncryptDecrypt.Encrypt()`
2. Comment out the current `<add name="Connections" ...>` line
3. Add the new encrypted string
4. Update `AllowedOrigins`, `ValidIssuer`, `ValidAudience` to match the new environment

---

## 15. Error Handling Strategy

### Logging

```
Exception in controller
  └─ bl.BL_WriteErrorMsginLog(moduleName, actionName, ex.Message)
      └─ Writes JSON entry to:
         {SupportFilePath}\Log File Errors\Log System Error-{ddMMyyyy}.json
```

Format per entry:
```json
{ "Module": "Invoice", "Action": "invoice/save", "Error": "...", "Time": "..." }
```

**`SupportFilePath`** defaults to `D:\\HOST\\NewWebShineSupport\\` — change this in `Web.config` for each environment.

### Response Codes

| Scenario | HTTP Status | Body |
|----------|-------------|------|
| Success (read) | 200 | `List<T>` JSON |
| Success (write) | 200 | `[{"ID":"<newId>","MsgID":"0","Message":"Saved Successfully"}]` |
| Business error from SP | 200 | `[{"ID":"0","MsgID":"1","Message":"<error text>"}]` |
| Unhandled exception | 200 | `null` (empty `Ok()`) |
| Auth failure | 401 | Unauthorized (from `[CookieAuthorize]`) |

> Clients should treat HTTP 200 with null/empty body as a server-side exception. Check `MsgID == "1"` for business errors.

---

*Last updated: October 2026*
