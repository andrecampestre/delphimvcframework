unit Entities;

interface

uses
  MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord,
  System.Classes,
  MVCFramework;

type

  [MVCNameCase(ncLowerCase)]
  [MVCTable('people')]
  [MVCEntityActions([eaCreate, eaRetrieve, eaUpdate, eaDelete])]
  TPerson = class(TMVCActiveRecord)
  private
    [MVCTableField('id', [foPrimaryKey, foAutoGenerated])]
    fID: Int64;
    [MVCTableField('LAST_NAME')]
    fLastName: string;
    [MVCTableField('FIRST_NAME')]
    fFirstName: string;
    [MVCTableField('DOB')]
    fDOB: TDate;
    [MVCTableField('FULL_NAME')]
    fFullName: string;
    [MVCTableField('IS_MALE')]
    fIsMale: Boolean;
    [MVCTableField('NOTE')]
    fNote: string;
    [MVCTableField('PHOTO')]
    fPhoto: TStream;

    // transient fields
    fAge: Integer;

    procedure SetLastName(const Value: string);
    procedure SetID(const Value: Int64);
    procedure SetFirstName(const Value: string);
    procedure SetDOB(const Value: TDate);
    function GetFullName: string;
    procedure SetIsMale(const Value: Boolean);
    procedure SetNote(const Value: string);
  protected
    procedure OnAfterLoad; override;
    procedure OnBeforeInsertOrUpdate; override;
    procedure OnValidation; override;
    procedure OnBeforeInsert; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    property ID: Int64 read fID write SetID;
    property LastName: string read fLastName write SetLastName;
    property FirstName: string read fFirstName write SetFirstName;
    property Age: Integer read fAge;
    property DOB: TDate read fDOB write SetDOB;
    property FullName: string read GetFullName;
    property IsMale: Boolean read fIsMale write SetIsMale;
    property Note: string read fNote write SetNote;
    property Photo: TStream read fPhoto;
  end;

  [MVCNameCase(ncLowerCase)]
  [MVCTable('PEOPLE')]
  [MVCEntityActions([eaCreate, eaRetrieve, eaUpdate, eaDelete])]
  TContact = class(TPerson)

  end;

  [MVCNameCase(ncLowerCase)]
  [MVCTable('phones')]
  [MVCEntityActions([eaCreate, eaRetrieve, eaUpdate, eaDelete])]
  TPhone = class(TMVCActiveRecord)
  private
    [MVCTableField('id', [foPrimaryKey, foAutoGenerated])]
    fID: Integer;
    [MVCTableField('phone_number')]
    fPhoneNumber: string;
    [MVCTableField('number_type')]
    fNumberType: string;
    [MVCTableField('id_person')]
    fIDPerson: Integer;
  protected
    procedure OnValidation; override;
  public
    property ID: Integer read fID write fID;
    property IDPerson: Integer read fIDPerson write fIDPerson;
    property PhoneNumber: string read fPhoneNumber write fPhoneNumber;
    property NumberType: string read fNumberType write fNumberType;
  end;

  [MVCNameCase(ncLowerCase)]
  [MVCTable('articles')]
  [MVCEntityActions([eaCreate, eaRetrieve, eaUpdate, eaDelete])]
  TArticle = class(TMVCActiveRecord)
  private
    [MVCTableField('id', [foPrimaryKey, foAutoGenerated])]
    fID: Int64;
    [MVCTableField('price')]
    FPrice: Currency;
    [MVCTableField('description')]
    FDescription: string;
    procedure SetID(const Value: Int64);
    procedure SetDescription(const Value: string);
    procedure SetPrice(const Value: Currency);
  public
    property ID: Int64 read fID write SetID;
    property Description: string read FDescription write SetDescription;
    property Price: Currency read FPrice write SetPrice;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils;

{ TPersona }

constructor TPerson.Create;
begin
  inherited;
  fPhoto := TMemoryStream.Create;
end;

destructor TPerson.Destroy;
begin
  fPhoto.Free;
  inherited;
end;

function TPerson.GetFullName: string;
begin
  Result := fFullName;
end;

procedure TPerson.OnAfterLoad;
begin
  inherited;
  fAge := Yearsbetween(fDOB, now);
end;

procedure TPerson.OnBeforeInsert;
begin
  inherited;
  // TMemoryStream(fPhoto).LoadFromFile('C:\DEV\dmvcframework\samples\_\customer_small.png');
end;

procedure TPerson.OnBeforeInsertOrUpdate;
begin
  inherited;
  fLastName := fLastName.ToUpper;
  fFirstName := fFirstName.ToUpper;
  fFullName := fFirstName + ' ' + fLastName;
end;

procedure TPerson.OnValidation;
begin
  inherited;
  if fLastName.Trim.IsEmpty or fFirstName.Trim.IsEmpty then
    raise EMVCActiveRecord.Create('Validation error. FirstName and LastName are required');
end;

procedure TPerson.SetLastName(const Value: string);
begin
  fLastName := Value;
end;

procedure TPerson.SetNote(const Value: string);
begin
  fNote := Value;
end;

procedure TPerson.SetDOB(const Value: TDate);
begin
  fDOB := Value;
end;

procedure TPerson.SetID(const Value: Int64);
begin
  fID := Value;
end;

procedure TPerson.SetIsMale(const Value: Boolean);
begin
  fIsMale := Value;
end;

procedure TPerson.SetFirstName(const Value: string);
begin
  fFirstName := Value;
end;

{ TArticle }

procedure TArticle.SetDescription(const Value: string);
begin
  FDescription := Value;
end;

procedure TArticle.SetID(const Value: Int64);
begin
  fID := Value;
end;

procedure TArticle.SetPrice(const Value: Currency);
begin
  FPrice := Value;
end;

{ TPhone }

procedure TPhone.OnValidation;
begin
  inherited;
  if fPhoneNumber.Trim.IsEmpty then
    raise EMVCActiveRecord.Create('Phone Number cannot be empty');
end;

initialization

ActiveRecordMappingRegistry.AddEntity('people', TPerson);
ActiveRecordMappingRegistry.AddEntity('contacts', TContact);
ActiveRecordMappingRegistry.AddEntity('phones', TPhone);
ActiveRecordMappingRegistry.AddEntity('articles', TArticle);

finalization

end.
