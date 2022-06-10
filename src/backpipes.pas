unit backpipes;

interface

{$I backpipes.defines.inc}

type
  TNotifyEvent<T> = procedure (
    Sender: TObject; 
    const data: T) of object;
  
  INotifiable<T> = interface
  ['{B90D0584-BB6F-4D87-9556-229E211B285E}']
    function Enabled: Boolean;
    procedure Handle(Sender: TObject; const data: T);
  end;

  IMessagePipe<TIn, TOut> = interface
    function Push(const msg: TIn): Boolean;
    procedure Subscribe(const observer: INotifiable<TOut>);
  end;

  TMessageHandlerFunc<TIn, TOut> = function (
    const intput: TIn; 
    out output: TOut): Boolean;

type
  PipeOf<TIn, TOut> = class
  public 
    class function Create(
      const handler: TMessageHandlerFunc<TIn, TOut>): IMessagePipe<TIn, TOut>; static;
  end;

implementation
uses
  // backpipes.types,
  // backpipes.classes,
  backpipes.workers;


class function PipeOf<TIn, TOut>.Create(
  const handler: TMessageHandlerFunc<TIn, TOut>): IMessagePipe<TIn, TOut>;
var 
  res: TCompositeMessagePipe<TIn, TOut>;
begin
  res := TCompositeMessagePipe<TIn, TOut>.Create(10, handler);
end;

end.