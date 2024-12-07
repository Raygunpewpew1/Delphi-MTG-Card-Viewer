﻿unit MLogic;

interface

uses
  System.SysUtils, System.IOUtils, System.Generics.Collections,
  System.RegularExpressions, System.Hash, System.Classes, System.NetEncoding,
  FMX.Dialogs, SGlobalsZ, FMX.Graphics, System.Net.HttpClient, FMX.StdCtrls,
  System.Threading, JsonDataObjects;

procedure CopyDatabaseToInternalStorage;
procedure InitializeManaSymbolMap;
function GetDatabasePath: string;
function GetAppPath: string;
function GetIconPath(const FileName: string): string;
function ParseTextWithSymbolsManual(const Input: string): TArray<string>;
function GetCacheDirectory: string;
function GetCachedImagePath(const URL: string): string;
function GetStatusClass(const LegalityStatus: string): string;
procedure SetupPopularCards(PopularCards: TStringList);
function ReplaceManaSymbolsWithImages(const OracleText: string): string;
function ImageToBase64(const ImagePath: string): string;
function GetLegalStatus(const Legalities: TCardLegalities;
  const FieldName: string): string;
function GetTemplatePath: string;
procedure CopyTemplateToInternalStorage;
function LoadTemplate(const FileName: string;
  const DefaultTemplate: string = ''): string;
function ReplacePlaceholder(const Template, Placeholder, Value: string): string;
function IsCardValid(const Card: TCardDetails): Boolean;
procedure SaveCatalogsToFile(const FileName: string;
const Catalogs: TDictionary<string, TScryfallCatalog>);
procedure LoadCatalogsFromFile(const FileName: string;
var Catalogs: TDictionary<string, TScryfallCatalog>);

var
  FManaSymbolMap: TDictionary<string, string>;
  FBase64ImageCache: TDictionary<string, string>;
  HttpClient: THTTPClient;

implementation

function GetDatabasePath: string;
begin
  // Android sandbox-compatible path
  Result := TPath.Combine(TPath.GetDocumentsPath, 'Collection.db');
end;

procedure CopyDatabaseToInternalStorage;
var
  SourcePath, DestinationPath: string;
begin
  DestinationPath := GetDatabasePath;

  // Only copy if the database does not already exist
  if not TFile.Exists(DestinationPath) then
  begin
{$IFDEF ANDROID}
    // Path to assets for Android
    SourcePath := TPath.Combine(TPath.GetDocumentsPath, 'Collection.db');
{$ELSE}
    // Path for Windows
    SourcePath := TPath.Combine(TPath.GetHomePath, 'Collection.db');
{$ENDIF}
    try
      if TFile.Exists(SourcePath) then
        TFile.Copy(SourcePath, DestinationPath)
      else
        raise Exception.Create('Database file not found: ' + SourcePath);
    except
      on E: Exception do
        ShowMessage('Error copying database: ' + E.Message);
    end;
  end;
end;

{ template }
function GetTemplatePath: string;
begin
  // Android sandbox-compatible path
  Result := TPath.Combine(TPath.GetDocumentsPath, 'card_template.html');
end;

procedure CopyTemplateToInternalStorage;
var
  SourcePath, DestinationPath: string;
begin
  DestinationPath := GetTemplatePath;

  // Only copy if the template does not already exist
  if not TFile.Exists(DestinationPath) then
  begin
{$IFDEF ANDROID}
    // Path to assets for Android
    SourcePath := TPath.Combine(TPath.GetDocumentsPath, 'card_template.html');
{$ELSE}
    // Path for Windows
    SourcePath := TPath.Combine(TPath.GetHomePath, 'card_template.html');
{$ENDIF}
    try
      if TFile.Exists(SourcePath) then
        TFile.Copy(SourcePath, DestinationPath)
      else
        raise Exception.Create('Template file not found: ' + SourcePath);
    except
      on E: Exception do
        ShowMessage('Error copying template: ' + E.Message);
    end;
  end;
end;

function LoadTemplate(const FileName: string;
  const DefaultTemplate: string = ''): string;
var
  FullPath: string;
begin
  CopyTemplateToInternalStorage;

  // Read the template from internal storage
  FullPath := TPath.Combine(TPath.GetDocumentsPath, FileName);
  if TFile.Exists(FullPath) then
    Result := TFile.ReadAllText(FullPath, TEncoding.UTF8)
  else if DefaultTemplate <> '' then
    Result := DefaultTemplate
  else
    raise Exception.Create('Template file not found: ' + FullPath);
end;

procedure InitializeManaSymbolMap;
begin
  if Assigned(FManaSymbolMap) then
    Exit; // Already initialized

  FManaSymbolMap := TDictionary<string, string>.Create;

  // Populate mana symbols
  FManaSymbolMap.Add('{T}', '{T}.png');
  FManaSymbolMap.Add('{W}', '{W}.png');
  FManaSymbolMap.Add('{U}', '{U}.png');
  FManaSymbolMap.Add('{B}', '{B}.png');
  FManaSymbolMap.Add('{R}', '{R}.png');
  FManaSymbolMap.Add('{G}', '{G}.png');
  FManaSymbolMap.Add('{C}', '{C}.png');
  FManaSymbolMap.Add('{X}', '{X}.png');
  FManaSymbolMap.Add('{A}', '{A}.png');
  FManaSymbolMap.Add('{H}', '{H}.png');
  FManaSymbolMap.Add('{Y}', '{Y}.png');
  FManaSymbolMap.Add('{Z}', '{Z}.png');

  for var i := 0 to 20 do
    FManaSymbolMap.Add('{' + i.ToString + '}', '{' + i.ToString + '}.png');

  FManaSymbolMap.Add('{½}', '{½}.png');
  FManaSymbolMap.Add('{∞}', '{∞}.png');
  FManaSymbolMap.Add('{100}', '{100}.png');
  FManaSymbolMap.Add('{1000000}', '{1000000}.png');
  FManaSymbolMap.Add('{W/U}', '{W_U}.png');
  FManaSymbolMap.Add('{W/B}', '{W_B}.png');
  FManaSymbolMap.Add('{U/B}', '{U_B}.png');
  FManaSymbolMap.Add('{U/R}', '{U_R}.png');
  FManaSymbolMap.Add('{B/R}', '{B_R}.png');
  FManaSymbolMap.Add('{B/G}', '{B_G}.png');
  FManaSymbolMap.Add('{R/G}', '{R_G}.png');
  FManaSymbolMap.Add('{R/W}', '{R_W}.png');
  FManaSymbolMap.Add('{G/W}', '{G_W}.png');
  FManaSymbolMap.Add('{G/U}', '{G_U}.png');
  FManaSymbolMap.Add('{W/P}', '{W_P}.png');
  FManaSymbolMap.Add('{U/P}', '{U_P}.png');
  FManaSymbolMap.Add('{B/P}', '{B_P}.png');
  FManaSymbolMap.Add('{R/P}', '{R_P}.png');
  FManaSymbolMap.Add('{G/P}', '{G_P}.png');
  FManaSymbolMap.Add('{B/G/P}', '{B_G_P}.png');
  FManaSymbolMap.Add('{G/W/P}', '{G_W_P}.png');
  FManaSymbolMap.Add('{U/B/P}', '{U_B_P}.png');
  FManaSymbolMap.Add('{W/B/P}', '{W_B_P}.png');
  FManaSymbolMap.Add('{W/U/P}', '{W_U_P}.png');
  FManaSymbolMap.Add('{B/R/P}', '{B_R_P}.png');

  FManaSymbolMap.Add('{Q}', '{Q}.png');
  FManaSymbolMap.Add('{S}', '{S}.png');
  FManaSymbolMap.Add('{E}', '{E}.png');
  FManaSymbolMap.Add('{P}', '{P}.png');
  FManaSymbolMap.Add('{PW}', '{PW}.png');
  FManaSymbolMap.Add('{HW}', '{HW}.png');
  FManaSymbolMap.Add('{HR}', '{HR}.png');
  FManaSymbolMap.Add('{TK}', '{TK}.png');

end;

function GetAppPath: string;
begin
  Result := TPath.GetDirectoryName(ParamStr(0));
end;

function GetIconPath(const FileName: string): string;
begin
{$IFDEF ANDROID}
  Result := TPath.Combine(TPath.GetDocumentsPath, TPath.Combine('MTGIconsPNG',
    FileName));
{$ELSE}
  Result := TPath.Combine(GetAppPath, TPath.Combine('MTGIconsPNG', FileName));
{$ENDIF}
end;

function ParseTextWithSymbolsManual(const Input: string): TArray<string>;
var
  Regex: TRegEx;
  Matches: TMatchCollection;
  Match: TMatch;
  PartsList: TList<string>;
begin
  PartsList := TList<string>.Create;
  try
    // Regular expression to match either {symbol} or plain text
    Regex := TRegEx.Create('\{[^}]+\}|[^{]+');

    // Find all matches in the input string
    Matches := Regex.Matches(Input);
    for Match in Matches do
      PartsList.Add(Match.Value);

    Result := PartsList.ToArray;
  finally
    PartsList.Free;
  end;
end;

function GetCacheDirectory: string;
begin
{$IFDEF ANDROID}
  // Use cache directory specific to Android
  Result := TPath.Combine(TPath.GetCachePath, 'MTGCardFetch');
{$ELSE}
  // Use documents directory for Windows
  Result := TPath.Combine(TPath.GetDocumentsPath, 'MTGCardFetch');
{$ENDIF}
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

function GetCachedImagePath(const URL: string): string;
var
  Hash: string;
  FileName: string;
begin
  // Use SHA2 hash to ensure unique filenames
  Hash := THashSHA2.GetHashString(URL);
  FileName := Hash;
  Result := TPath.Combine(GetCacheDirectory, FileName);
end;

function GetStatusClass(const LegalityStatus: string): string;
begin
  if SameText(LegalityStatus, 'legal') then
    Result := 'legal'
  else if SameText(LegalityStatus, 'not_legal') then
    Result := 'not legal'
  else if SameText(LegalityStatus, 'banned') then
    Result := 'banned'
  else if SameText(LegalityStatus, 'restricted') then
    Result := 'restricted'
  else
    Result := 'unknown';
end;

procedure SetupPopularCards(PopularCards: TStringList);
begin
  PopularCards.Clear;
  PopularCards.AddStrings(['Black Lotus', 'Ancestral Recall', 'Mox Sapphire',
    'Mox Jet', 'Mox Ruby', 'Mox Pearl', 'Mox Emerald', 'Time Walk',
    'Timetwister', 'Tarmogoyf', 'Jace, the Mind Sculptor',
    'Liliana of the Veil', 'Force of Will', 'Snapcaster Mage', 'Dark Confidant',
    'Lightning Bolt', 'Birds of Paradise', 'Serra Angel', 'Shivan Dragon',
    'Swords to Plowshares', 'Brainstorm', 'Counterspell', 'Sol Ring',
    'Mana Crypt', 'Mana Vault', 'Ancient Tomb', 'Bazaar of Baghdad',
    'Library of Alexandria', 'The Tabernacle at Pendrell Vale',
    'Gaea''s Cradle', 'Nicol Bolas, the Ravager', 'Teferi, Hero of Dominaria',
    'Elspeth, Sun''s Champion', 'Primeval Titan', 'Emrakul, the Aeons Torn',
    'Ulamog, the Infinite Gyre', 'Blightsteel Colossus', 'Aether Vial',
    'Sensei''s Divining Top', 'Thalia, Guardian of Thraben', 'Noble Hierarch',
    'Deathrite Shaman', 'Wasteland', 'Strip Mine', 'Blood Moon', 'Thoughtseize',
    'Inquisition of Kozilek', 'Cabal Therapy', 'Yawgmoth''s Will', 'Tinker',
    'Demonic Tutor', 'Vampiric Tutor', 'Mystical Tutor', 'Enlightened Tutor',
    'Imperial Seal', 'Necropotence', 'Phyrexian Arena', 'Sylvan Library',
    'Lotus Petal', 'Chrome Mox', 'Grim Monolith', 'Lion''s Eye Diamond',
    'Arcbound Ravager', 'Chalice of the Void', 'Karn Liberated',
    'Ugin, the Spirit Dragon', 'Cryptic Command', 'Thought-Knot Seer',
    'Reality Smasher', 'Scalding Tarn', 'Misty Rainforest', 'Verdant Catacombs',
    'Polluted Delta', 'Flooded Strand', 'Platinum Angel', 'Eternal Witness',
    'Dark Ritual', 'Gilded Lotus', 'Birthing Pod', 'Hullbreacher',
    'Opposition Agent', 'Dockside Extortionist', 'Rhystic Study',
    'Mystic Remora', 'Mother of Runes', 'Stoneforge Mystic',
    'Sword of Fire and Ice', 'Sword of Feast and Famine', 'Batterskull',
    'Sigarda, Host of Herons', 'Zur the Enchanter', 'Atraxa, Praetors'' Voice',
    'Edgar Markov', 'Marrow-Gnawer', 'Krenko, Mob Boss',
    'Prossh, Skyraider of Kher', 'Meren of Clan Nel Toth', 'The Gitrog Monster',
    'Omnath, Locus of Creation', 'Karn, the Great Creator',
    'Oko, Thief of Crowns', 'Thassa''s Oracle', 'Underworld Breach']);

end;

function ImageToBase64(const ImagePath: string): string;
begin
  if FBase64ImageCache.TryGetValue(ImagePath, Result) then
    Exit; // Return cached value

  if not TFile.Exists(ImagePath) then
  begin
    Result := '';
    Exit;
  end;

  var
    Bytes: TBytes := TFile.ReadAllBytes(ImagePath);
  Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  FBase64ImageCache.Add(ImagePath, Result);

end;

function ReplaceManaSymbolsWithImages(const OracleText: string): string;
var
  Parts: TArray<string>;
  Part: string;
  ImageFileName: string;
  ImagePath, ImageBase64: string;
  ImageMimeType: string;
begin
  Result := ''; // Initialize the result string
  Parts := ParseTextWithSymbolsManual(OracleText);
  // Split OracleText into parts

  for Part in Parts do
  begin
    if Part.StartsWith('{') and Part.EndsWith('}') then
    begin
      // Look up the mana symbol image file
      if FManaSymbolMap.TryGetValue(Part, ImageFileName) then
        ImagePath := GetIconPath(ImageFileName)
      else
        ImagePath := GetIconPath('default.png'); // Fallback to default image

      // Validate the image file
      if not TFile.Exists(ImagePath) then
        ImagePath := GetIconPath('default.png');

      // Convert the image to Base64
      ImageBase64 := ImageToBase64(ImagePath);
      if ImageBase64 = '' then
        Continue; // Skip if conversion failed

      // Determine the MIME type based on the file extension
      if ImagePath.EndsWith('.png', True) then
        ImageMimeType := 'image/png'
      else if ImagePath.EndsWith('.jpg', True) or
        ImagePath.EndsWith('.jpeg', True) then
        ImageMimeType := 'image/jpeg'
      else if ImagePath.EndsWith('.gif', True) then
        ImageMimeType := 'image/gif'
      else
        ImageMimeType := 'application/octet-stream'; // Default MIME type

      // Construct the data URI
      ImagePath := Format('data:%s;base64,%s', [ImageMimeType, ImageBase64]);

      // Append the <img> tag with improved vertical alignment
      Result := Result +
        Format('<img src="%s" alt="%s" style="display:inline-block; width:16px; height:16px; vertical-align:middle; margin:0 2px;">',
        [ImagePath, TNetEncoding.HTML.Encode(Part)]);
    end
    else
    begin
      // Append plain text, properly encoded
      Result := Result + TNetEncoding.HTML.Encode(Part);
    end;
  end;
end;

function GetLegalStatus(const Legalities: TCardLegalities;
  const FieldName: string): string;
begin
  if FieldName = 'Standard' then
    Result := Legalities.Standard
  else if FieldName = 'Pioneer' then
    Result := Legalities.Pioneer
  else if FieldName = 'Modern' then
    Result := Legalities.Modern
  else if FieldName = 'Legacy' then
    Result := Legalities.Legacy
  else if FieldName = 'Commander' then
    Result := Legalities.Commander
  else if FieldName = 'Vintage' then
    Result := Legalities.Vintage
  else if FieldName = 'Pauper' then
    Result := Legalities.Pauper
  else if FieldName = 'Historic' then
    Result := Legalities.Historic
  else if FieldName = 'Explorer' then
    Result := Legalities.Explorer
  else if FieldName = 'Alchemy' then
    Result := Legalities.Alchemy
  else if FieldName = 'Brawl' then
    Result := Legalities.Brawl
  else if FieldName = 'Future' then
    Result := Legalities.Future
  else if FieldName = 'Oldschool' then
    Result := Legalities.Oldschool
  else if FieldName = 'Premodern' then
    Result := Legalities.Premodern
  else if FieldName = 'Duel' then
    Result := Legalities.Duel
  else if FieldName = 'Penny' then
    Result := Legalities.Penny
  else
    Result := '';
end;

procedure LoadCachedOrDownloadImage(const URL: string; Bitmap: TBitmap);
var
  FilePath: string;
  MemoryStream: TMemoryStream;
begin
  FilePath := GetCachedImagePath(URL);

  if TFile.Exists(FilePath) then
  begin
    Bitmap.LoadFromFile(FilePath);

  end
  else
  begin
    MemoryStream := TMemoryStream.Create;
    try
      try
        HttpClient.Get(URL, MemoryStream);
        MemoryStream.Position := 0;
        MemoryStream.SaveToFile(FilePath);
        MemoryStream.Position := 0;
        Bitmap.LoadFromStream(MemoryStream);

      except
        on E: ENetHTTPRequestException do
          TThread.Queue(nil,
            procedure
            begin
              ShowMessage('Network error: ' + E.Message);
            end);
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowMessage('Error loading image: ' + E.Message);
            end);
      end;
    finally
      MemoryStream.Free;
    end;
  end;
end;

procedure LoadCachedOrDownloadImageAsync(const URL: string;
ImageControl: TImageControl);
begin
  TTask.Run(
    procedure
    var
      Bitmap: TBitmap;
    begin
      Bitmap := TBitmap.Create;
      try
        LoadCachedOrDownloadImage(URL, Bitmap);
        TThread.Synchronize(nil,
          procedure
          begin
            ImageControl.Bitmap.Assign(Bitmap);
          end);
      finally
        Bitmap.Free;
      end;
    end);
end;

function ReplacePlaceholder(const Template, Placeholder, Value: string): string;
begin
  Result := StringReplace(Template, '{{' + Placeholder + '}}', Value,
    [rfReplaceAll]);
end;

function IsCardValid(const Card: TCardDetails): Boolean;
begin
  Result := not Card.CardName.IsEmpty and not Card.SFID.IsEmpty;
end;


procedure SaveCatalogsToFile(const FileName: string; const Catalogs: TDictionary<string, TScryfallCatalog>);
var
  AppDirectory, FullFilePath: string;
  JsonCatalogs: TJsonObject;
  CatalogName: string;
  CatalogData: TJsonArray;
  Catalog: TScryfallCatalog;
begin
  // Determine the platform-specific file path and subdirectory
  {$IF DEFINED(MSWINDOWS)}
  AppDirectory := TPath.Combine(TPath.GetDocumentsPath, 'MTGCardFetch');
  {$ELSEIF DEFINED(ANDROID)}
  AppDirectory := TPath.Combine(TPath.GetSharedDocumentsPath, 'MTGCardFetch');
  {$ELSE}
  raise Exception.Create('Unsupported platform');
  {$ENDIF}

  // Ensure the subdirectory exists
  if not ForceDirectories(AppDirectory) then
    raise Exception.CreateFmt('Failed to create directory: %s', [AppDirectory]);

  // Combine the app directory with the filename
  FullFilePath := TPath.Combine(AppDirectory, FileName);

  // Create a JSON object to hold the catalogs
  JsonCatalogs := TJsonObject.Create;
  try
    for CatalogName in Catalogs.Keys do
    begin
      Catalog := Catalogs[CatalogName];

      // Create a JSON array for the catalog data
      CatalogData := TJsonArray.Create;
      for var Item in Catalog.Data do
        CatalogData.Add(Item);

      // Add the catalog name, data, and metadata to the JSON object
      JsonCatalogs.O[CatalogName] := TJsonObject.Create;
      JsonCatalogs.O[CatalogName].S['name'] := Catalog.Name;
      JsonCatalogs.O[CatalogName].A['data'] := CatalogData;
      JsonCatalogs.O[CatalogName].I['total_items'] := Catalog.TotalItems;
    end;

    // Save the JSON object to the file
    JsonCatalogs.SaveToFile(FullFilePath, False, TEncoding.UTF8, True);
  finally
   JsonCatalogs.Free;
  end;
end;

procedure LoadCatalogsFromFile(const FileName: string; var Catalogs: TDictionary<string, TScryfallCatalog>);
var
  AppDirectory, FullFilePath: string;
  JsonCatalogs: TJsonObject;
  CatalogName: string;
  CatalogObj: TJsonObject;
  Catalog: TScryfallCatalog;
  CatalogDataArray: TJsonArray;
begin
  // Determine the platform-specific file path and subdirectory
  {$IF DEFINED(MSWINDOWS)}
  AppDirectory := TPath.Combine(TPath.GetDocumentsPath, 'MTGCardFetch');
  {$ELSEIF DEFINED(ANDROID)}
  AppDirectory := TPath.Combine(TPath.GetSharedDocumentsPath, 'MTGCardFetch');
  {$ELSE}
  raise Exception.Create('Unsupported platform');
  {$ENDIF}

  // Combine the app directory with the filename
  FullFilePath := TPath.Combine(AppDirectory, FileName);

  // Ensure the file exists; if not, create an empty dictionary and exit
  if not TFile.Exists(FullFilePath) then
  begin
    Catalogs.Clear; // Clear any existing data
    Exit;
  end;

  // Load the JSON object from the file
  JsonCatalogs := TJsonObject.Create;
  try
    try
      JsonCatalogs.LoadFromFile(FullFilePath);
    except
      on E: Exception do
      begin
        // Handle invalid file format by clearing the dictionary and exiting
        Catalogs.Clear;
        raise Exception.CreateFmt('Failed to load catalogs: %s', [E.Message]);
      end;
    end;

    // Clear the existing catalog dictionary to avoid conflicts
    Catalogs.Clear;

    // Iterate through the catalogs in the JSON file
    for var I := 0 to JsonCatalogs.Count - 1 do
    begin
      CatalogName := JsonCatalogs.Names[I]; // Get the catalog name
      CatalogObj := JsonCatalogs.O[CatalogName]; // Get the catalog object
      Catalog.Name := CatalogObj.S['name'];
      Catalog.TotalItems := CatalogObj.I['total_items'];

      // Load the catalog's data array
      CatalogDataArray := CatalogObj.A['data'];
      SetLength(Catalog.Data, CatalogDataArray.Count);
      for var J := 0 to CatalogDataArray.Count - 1 do
        Catalog.Data[J] := CatalogDataArray.S[J];

      // Add the catalog to the dictionary
      Catalogs.Add(CatalogName, Catalog);
    end;
  finally
    JsonCatalogs.Free;
  end;
end;

initialization

InitializeManaSymbolMap;

finalization

FManaSymbolMap.Free;

end.
