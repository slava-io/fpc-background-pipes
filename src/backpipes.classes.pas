unit backpipes.classes;

interface

{$I backpipes.defines.inc}

uses
  classes,
  syncobjs,
  backpipes;

type
  TPipeItem<T> = record
    Msg: T;
  end;

  TPipeItemArray<T> = array of TPipeItem<T>;  

type
  TMessagePipe<T> = class
  private
    fIndexToPush: Cardinal;
    fIndexToPull: Cardinal;
    fCapacity: Cardinal;
    fPushed: TEvent;
    fPulled: TEvent;
    fItems: TPipeItemArray<T>;
  public
    function Pulling(var item: TPipeItem<T>): Boolean;
    function Pushing(const item: TPipeItem<T>): Boolean;  
    property Pulled: TEvent read fPulled;
    property Pushed: TEvent read fPushed;
  public 
    constructor Create(capacity: Cardinal);
    destructor Destroy; override;
  end;

  TNotifiableList<T> = class(TThreadList)
  public
    procedure Add(const notifiable: INotifiable<T>);
    procedure Remove(const notifiable: INotifiable<T>);
    procedure Invoke(Sender: TObject; const data: T); 
  end;

implementation

constructor TMessagePipe<T>.Create(capacity: Cardinal);
begin
  inherited Create;
  fIndexToPush := 0;
  fIndexToPull := 0;
  fCapacity := capacity;
  SetLength(fItems, capacity); 
  fPushed := TEvent.Create(nil, False, False, 'item_pushed_sync_event');
  fPulled := TEvent.Create(nil, False, False, 'item_pulled_sync_event');
end;

function TMessagePipe<T>.Pulling(var item: TPipeItem<T>): Boolean;
var 
  next: Cardinal;
begin
  // nothing new to pull
  if fIndexToPull = fIndexToPush then
    Exit(False); 

  item.Msg := fItems[fIndexToPull].Msg;
  next := Succ(fIndexToPull);
  if next >= fCapacity then
    next := 0;
  fIndexToPull := next;

  fPulled.SetEvent;
  Result := True;  
end;

function TMessagePipe<T>.Pushing(const item: TPipeItem<T>): Boolean;
var 
  next: Cardinal;
begin
  next := Succ(fIndexToPush);
  //the capacity has been reached, go to the next cycle
  if next >= fCapacity then
    next := 0;
  //cannot outrun the pull index  
  if next = fIndexToPull then
    Exit(False); 

  fItems[fIndexToPush].Msg := item.Msg;
  fIndexToPush := next;
  
  fPushed.SetEvent;
  Result := True;
end;

procedure TNotifiableList<T>.Add(const notifiable: INotifiable<T>);
var
  list: TList;
begin
  list := Self.LockList;
  try
    list.Add(PPointer(notifiable)^);
  finally
    Self.UnlockList;
  end;
end;

procedure TNotifiableList<T>.Remove(const notifiable: INotifiable<T>);
var
  list: TList;
begin
  list := Self.LockList;
  try
    list.Remove(PPointer(notifiable)^);
  finally
    Self.UnlockList;
  end;  
end;

procedure TNotifiableList<T>.Invoke(Sender: TObject; const data: T);
var
  list: TList;
  item: Pointer;
  notifiable: INotifiable<T>;
begin
  list := Self.LockList;
  try
    for item in list do
    begin
      notifiable := INotifiable<T>(item);
      if not notifiable.Enabled then
        Continue;

      notifiable.Handle(Sender, data);  
    end;  
  finally
    Self.UnlockList;
  end; 
end;

destructor TMessagePipe<T>.Destroy;
begin
  SetLength(fItems, 0);
  inherited;
end;

end.