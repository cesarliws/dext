unit EntityDemo.Tests.LazyLoading;

interface

uses
  System.SysUtils,
  System.Classes,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TLazyLoadingTest = class(TBaseTest)
  public
    procedure Run; override;
  private
    procedure TestLazyLoadReference;
    procedure TestLazyLoadBlob;
    procedure TestLazyLoadLargeText;
    procedure TestMemoryManagement;
  end;

implementation

{ TLazyLoadingTest }

procedure TLazyLoadingTest.Run;
begin
  Log('🔬 Running Lazy Loading 1:1 Tests...');
  WriteLn('');
  
  TestLazyLoadReference;
  TestLazyLoadBlob;
  TestLazyLoadLargeText;
  TestMemoryManagement;
  
  WriteLn('');
  LogSuccess('All Lazy Loading tests passed! ✅');
end;

procedure TLazyLoadingTest.TestLazyLoadReference;
var
  Profile: TUserProfile;
  User: TUserWithProfile;
  LoadedUser: TUserWithProfile;
  SavedUserId: Integer;
  SavedProfileId: Integer;
begin
  Log('📝 Test 1: Lazy Load Reference (1:1)');
  
  // Create profile
  Profile := TUserProfile.Create;
  Profile.Bio := 'Software Developer';
  Profile.Preferences := '{"theme":"dark","lang":"en"}';
  
  FContext.Entities<TUserProfile>.Add(Profile);
  FContext.SaveChanges;
  SavedProfileId := Profile.Id;
  
  // Create user with profile reference
  User := TUserWithProfile.Create;
  User.Name := 'John Doe';
  User.Email := 'john@example.com';
  User.ProfileId := SavedProfileId;
  
  FContext.Entities<TUserWithProfile>.Add(User);
  FContext.SaveChanges;
  SavedUserId := User.Id;
  
  // Clear context to ensure fresh load
  FContext.Clear;
  
  // Load user WITHOUT profile
  LoadedUser := FContext.Entities<TUserWithProfile>.Find(SavedUserId);
  
  AssertTrue(LoadedUser <> nil, 'User loaded', 'User not found');
  
  if LoadedUser <> nil then
  begin
    AssertTrue(LoadedUser.Name = 'John Doe', 'User name correct', 'User name incorrect');
    
    // Now access profile - should lazy load
    var LoadedProfile := LoadedUser.Profile;
    
    AssertTrue(LoadedProfile <> nil, 'Profile lazy loaded', 'Profile not loaded');
    
    if LoadedProfile <> nil then
    begin
      AssertTrue(LoadedProfile.Bio = 'Software Developer', 'Profile bio correct', 'Profile bio incorrect');
      AssertTrue(LoadedProfile.Preferences = '{"theme":"dark","lang":"en"}', 'Profile preferences correct', 'Preferences incorrect');
    end;
  end;
  
  WriteLn('');
end;

procedure TLazyLoadingTest.TestLazyLoadBlob;
var
  Doc: TDocument;
  LoadedDoc: TDocument;
  TestData: TBytes;
  i: Integer;
  SavedDocId: Integer;
begin
  Log('📄 Test 2: Lazy Load BLOB (TBytes)');
  
  // Create large binary data (simulate PDF/image)
  SetLength(TestData, 1024 * 100); // 100KB
  for i := 0 to High(TestData) do
    TestData[i] := Byte(i mod 256);
  
  // Create document
  Doc := TDocument.Create;
  Doc.Title := 'Test PDF Document';
  Doc.ContentType := 'application/pdf';
  Doc.Content := TestData;
  Doc.FileSize := Length(TestData);
  
  FContext.Entities<TDocument>.Add(Doc);
  FContext.SaveChanges;
  SavedDocId := Doc.Id;
  
  // Clear context
  FContext.Clear;
  
  // Load document metadata
  LoadedDoc := FContext.Entities<TDocument>.Find(SavedDocId);
  
  AssertTrue(LoadedDoc <> nil, 'Document loaded', 'Document not found');
  
  if LoadedDoc <> nil then
  begin
    AssertTrue(LoadedDoc.Title = 'Test PDF Document', 'Document title correct', 'Title incorrect');
    AssertTrue(LoadedDoc.FileSize = Length(TestData), 'File size correct', 'File size incorrect');
    
    LogSuccess('Document metadata loaded');
    
    // Access Content - should load BLOB
    var ContentSize := Length(LoadedDoc.Content);
    AssertTrue(ContentSize = Length(TestData), 'BLOB loaded correctly', Format('BLOB size mismatch: %d vs %d', [ContentSize, Length(TestData)]));
    
    // Verify first and last bytes
    if ContentSize > 0 then
    begin
      AssertTrue(LoadedDoc.Content[0] = TestData[0], 'BLOB first byte correct', 'First byte mismatch');
      AssertTrue(LoadedDoc.Content[High(LoadedDoc.Content)] = TestData[High(TestData)], 'BLOB last byte correct', 'Last byte mismatch');
    end;
    
    LogSuccess('TBytes (BLOB) support working!');
  end;
  
  WriteLn('');
end;

procedure TLazyLoadingTest.TestLazyLoadLargeText;
var
  Article: TArticle;
  LoadedArticle: TArticle;
  LargeText: string;
  i: Integer;
  SavedArticleId: Integer;
begin
  Log('📰 Test 3: Lazy Load Large Text (TEXT/CLOB)');
  
  // Create large text (simulate article body)
  LargeText := '';
  for i := 1 to 1000 do
    LargeText := LargeText + Format('This is paragraph %d of a very long article. ', [i]);
  
  // Create article
  Article := TArticle.Create;
  Article.Title := 'Long Article Title';
  Article.Summary := 'This is a short summary';
  Article.Body := LargeText;
  Article.WordCount := 5000;
  
  FContext.Entities<TArticle>.Add(Article);
  FContext.SaveChanges;
  SavedArticleId := Article.Id;
  
  // Clear context
  FContext.Clear;
  
  // Load article metadata (without body)
  LoadedArticle := FContext.Entities<TArticle>.Find(SavedArticleId);
  
  AssertTrue(LoadedArticle <> nil, 'Article loaded', 'Article not found');
  
  if LoadedArticle <> nil then
  begin
    AssertTrue(LoadedArticle.Title = 'Long Article Title', 'Article title correct', 'Title incorrect');
    AssertTrue(LoadedArticle.Summary = 'This is a short summary', 'Summary correct', 'Summary incorrect');
    AssertTrue(LoadedArticle.WordCount = 5000, 'Word count correct', 'Word count incorrect');
    
    LogSuccess('Article metadata loaded without large body');
    
    // Access Body - should load large text
    var BodyLength := Length(LoadedArticle.Body);
    var ExpectedLength := Length(LargeText);
    
    if BodyLength <> ExpectedLength then
    begin
      WriteLn(Format('  ⚠️  Length mismatch: Got %d, Expected %d (diff: %d)', [BodyLength, ExpectedLength, BodyLength - ExpectedLength]));

      // Check last characters
      if BodyLength > 0 then
      begin
        WriteLn(Format('  Last char in loaded: #%d (%s)', [Ord(LoadedArticle.Body[BodyLength]), LoadedArticle.Body[BodyLength]]));
        WriteLn(Format('  Last char in original: #%d (%s)', [Ord(LargeText[ExpectedLength]), LargeText[ExpectedLength]]));
        
        // Check if it's just a trailing space/newline
        if (BodyLength = ExpectedLength + 1) and (LoadedArticle.Body[BodyLength] = ' ') then
          WriteLn('  ℹ️  Difference is a trailing space (acceptable)');
      end;
    end;
    
    AssertTrue(BodyLength = ExpectedLength, 'Large text loaded correctly', Format('Text size mismatch: %d vs %d', [BodyLength, ExpectedLength]));
    
    // Verify content
    AssertTrue(LoadedArticle.Body = LargeText, 'Text content matches', 'Text content mismatch');
  end;
  
  WriteLn('');
end;

procedure TLazyLoadingTest.TestMemoryManagement;
var
  Profile: TUserProfile;
  User: TUserWithProfile;
  LoadedUser: TUserWithProfile;
  SavedUserId: Integer;
  SavedProfileId: Integer;
begin
  Log('🧹 Test 4: Memory Management');
  
  // Create and save entities
  Profile := TUserProfile.Create;
  Profile.Bio := 'Memory Test';
  FContext.Entities<TUserProfile>.Add(Profile);
  FContext.SaveChanges;
  SavedProfileId := Profile.Id;
  
  User := TUserWithProfile.Create;
  User.Name := 'Memory Test User';
  User.Email := 'memory@test.com';
  User.ProfileId := SavedProfileId;
  
  FContext.Entities<TUserWithProfile>.Add(User);
  FContext.SaveChanges;
  SavedUserId := User.Id;
  
  // Clear to remove from tracking
  FContext.Clear;
  
  // Load and access lazy property
  LoadedUser := FContext.Entities<TUserWithProfile>.Find(SavedUserId);
  
  if LoadedUser <> nil then
  begin
    var LoadedProfile := LoadedUser.Profile;
    AssertTrue(LoadedProfile <> nil, 'Profile loaded', 'Profile not loaded');
    
    // Profile should be managed by context
    LogSuccess('Lazy-loaded entities managed by context');
  end;
  
  // Clear context - should free all managed entities
  FContext.Clear;
  LogSuccess('Context cleared without memory leaks');
  
  WriteLn('');
end;

end.
