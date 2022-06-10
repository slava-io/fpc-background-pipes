unit backpipes.workers;

interface

{$I backpipes.defines.inc}

uses
  classes,
  // backpipes.types,
  backpipes,
  backpipes.classes;

type
  TPipeListener<T> = class abstract(TThread)
  private
    fPipe: TMessagePipe<T>;
  protected
    procedure Received(const item: TPipeItem<T>); virtual; abstract;
    procedure Execute; override;
  public 
    constructor Create(const pipe: TMessagePipe<T>); reintroduce;
  end;

  TMessageWorker<TIn, TOut> = class(TPipeListener<TIn>)
  private
    fHandler: TMessageHandlerFunc<TIn, TOut>;
    fOutflow: TMessagePipe<T>;
  protected
    procedure Received(const item: TPipeItem<T>); override;
  public
    constructor Create(
      const inflow: TMessagePipe<T>;
      const handler: TMessageHandlerFunc<TIn, TOut>;
      const outflow: TMessagePipe<T> = nil);  
  end;

  TMessageDispatcher<T> = class(TPipeListener<T>)
  private
    fTarget: TNotifiableList<T>;
  protected
    procedure Received(const item: TPipeItem<T>); override;      
  public 
    constructor Create(
      const pipe: TMessagePipe<T>; 
      const target: TNotifiableList<T>);
  end;

type
  TCompositeMessagePipe<TIn, TOut> = class (TInterfacedObject, IMessagePipe<TIn, TOut>)
  private
    fInflow: TMessagePipe<TIn>;
    fOutflow: TMessagePipe<TOut>;
    fWorker: TMessageWorker<TIn, TOut>;
    fSubscribers: TNotifiableList<TOut>;
    fDispatcher: TMessageDispatcher<TOut>;
  protected
    function Push(const msg: TIn): Boolean;
    procedure Subscribe(const observer: INotifiable<TOut>);
  public
    constructor Create(
      const capacity: Cardinal;
      const handler: TMessageHandlerFunc<TIn, TOut>);
    destructor Destroy; override;
  end;


implementation

uses
  sysutils,
  syncobjs;

procedure TPipeListener<T>.Execute;
var
  tst: Integer;
  item: TPipeItem<T>;
begin
  try
    while not Self.Terminated do
    begin
      item := Default(TPipeItem<T>);
      case fPipe.Pushed.WaitFor(2000) of 
        wrSignaled: 
          begin
            while not Self.Terminated and fPipe.Pulling(item) do
              Received(item);   
          end;
        wrTimeout:;
        wrAbandoned:; //TODO
        wrError:; //TODO
      else
        raise EInvalidOperation.Create('ErrorMessage');
      end;

      // TPipeAccess<T>(fPipe)
      
    end;
  except
    on E: Exception do
    begin
      
    end;
  end;
  
end;

constructor TPipeListener<T>.Create(const pipe: TMessagePipe<T>);
begin
  inherited Create(True);
  fPipe := pipe; 
end;

constructor TMessageDispatcher<T>.Create(const pipe: TMessagePipe<T>; 
  const target: TNotifiableList<T>);
begin
  inherited Create(pipe);
  fTarget := target;
end;

procedure TMessageDispatcher<T>.Received(const item: TPipeItem<T>);
begin
  fTarget.Invoke(Self, item.Msg)
end;

procedure TMessageWorker<TIn,TOut>.Received(const item: TPipeItem<T>);
var
  res: TOut;
  itemToPush: TPipeItem<T>;
begin
  if Assigned(fHandler) and fHandler(item.Msg, res) and Assigned(fOutflow) then
  begin
    itemToPush := Default(TPipeItem<T>);
    itemToPush.Msg := res;
    fOutflow.Pushing(itemToPush);
  end;  
end;

constructor TMessageWorker<TIn,TOut>.Create(
  const inflow: TMessagePipe<T>; 
  const handler: TMessageHandlerFunc<TIn, TOut>; 
  const outflow: TMessagePipe<T>);
begin
  inherited Create(inflow);
  fHandler := handler;
  fOutflow := outflow;
end;

function TCompositeMessagePipe<TIn, TOut>.Push(const msg: TIn): Boolean;
var 
  item: TPipeItem<TIn>;
begin
  item := Default(TPipeItem<TIn>);
  item.Msg := msg;
  Result := fInflow.Pushing(item);
end;

procedure TCompositeMessagePipe<TIn, TOut>.Subscribe(const observer: INotifiable<TOut>);
begin
  fSubscribers.Add(observer);
end;

constructor TCompositeMessagePipe<TIn, TOut>.Create(
  const capacity: Cardinal;
  const handler: TMessageHandlerFunc<TIn, TOut>);
begin
  fInflow := TMessagePipe<TIn>.Create(capacity);
  fOutflow := TMessagePipe<TIn>.Create(capacity);
  fSubscribers := TNotifiableList<TIn>.Create;
  fWorker := TMessageWorker<TIn, TOut>.Create(fInflow, handler, fOutflow);
  fDispatcher := TMessageDispatcher<TOut>.Create(fOutflow, fSubscribers);
end;

destructor TCompositeMessagePipe<TIn, TOut>.Destroy;
begin
  fWorker.Terminate;
  fWorker.WaitFor;
  fInflow.Free;

  fDispatcher.Terminate;
  fDispatcher.WaitFor;
  fOutflow.Free;
  fSubscribers.Free;

  inherited;
end;

end.