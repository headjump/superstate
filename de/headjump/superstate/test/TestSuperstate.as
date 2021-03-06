package de.headjump.superstate.test {
import de.headjump.Helper;
import de.headjump.superstate.Superstate;
import de.headjump.superstate.SuperstateMachine;
import de.headjump.tests.OkTest;

public class TestSuperstate extends OkTest {
  public function TestSuperstate(test_method:String = null) {
    super(test_method);
  }

  public function testInitVals():void {
    var m:SuperstateMachine = new SuperstateMachine({});
    nok(!!m.current, "init vals all null");
    nok(!!m.current_enter_path);
    nok(!!m.current_exit_path);
    nok(!!m.current_from);
    nok(!!m.current_to);
  }

  public function testByName():void {
    var s_idle:Superstate = new Superstate();
    var s_deep:Superstate = new Superstate();
    var s_parent:Superstate;

    eq(s_idle.name, "", "init name blank");

    var m:SuperstateMachine = new SuperstateMachine({
      idle: s_idle,
      something: s_parent = new Superstate(null, {
        deep: s_deep
      })
    });

    eq(s_idle.name, "idle", "machine sets names");
    eq(s_deep.name, "deep", "machine sets deep names");
    eq(s_parent.name, "something", "machine sets deep names");

    eq(m.stateByName("idle"), m.stateByName("idle"), "same object when same name");

    eq(m.stateByName("idle"), s_idle, "find 'idle'");
    eq(s_deep, m.stateByName("something.deep"), "find with parent");
    eq(s_parent, m.stateByName("something"), "find parent");
    neq(s_deep, m.stateByName("something.bla.deep"), "unfind with wrong parent");
    neq(s_deep, m.stateByName("thing.deep"), "unfind with wrong parent");
    neq(s_deep, m.stateByName("deep.bla"), "unfind with wrong parent");
  }

  public function testErrorWhenNameNotDistinct():void {
    var m:SuperstateMachine = new SuperstateMachine({
      parent: new Superstate(null, {
        child: new Superstate(null, {
          child: new Superstate()
        })
      })
    });

    raises(Error, function():void {
      m.stateByName("child");
    });
  }

  private function sampleMachine(hook_output:Array = null):SuperstateMachine {
    var hooks:Function = function(id:String):Object {
      return {
        enter: function():void {
          if(hook_output) {
            hook_output.push("in:"+id);
          }
        },
        exit: function():void {
          if(hook_output) {
            hook_output.push("out:"+id);
          }
        }
      }
    };

    return new SuperstateMachine({
      one: new Superstate(hooks("1"), {
        two: new Superstate(hooks("2"), {
          three: new Superstate(hooks("3")),
          another_three: new Superstate(hooks("3b"))
        })
      }),
      uno: new Superstate(hooks("a"), {
        dos: new Superstate(hooks("b"), {
          tres: new Superstate(hooks("c"))
        })
      })
    });
  }

  public function testPathFromRoot():void {
    var m:SuperstateMachine = sampleMachine();

    ok(!!m.stateByName("three"));
    var p:Array = m.pathFromRootFor(m.stateByName("three"));
    eqArray(p, [m.stateByName("one"), m.stateByName("two")], "Path from root in order without self");

    p = m.pathFromRootFor(m.stateByName("one"));
    eqArray(p, [], "empty path from root without self");
  }

  public function testMoveUp():void {
    var m:SuperstateMachine = sampleMachine();

    var paths:Array = m.exitAndEnterPathsFromTo(m.stateByName("three"), m.stateByName("one"));

    eqArray(paths[0], [m.stateByName("three"), m.stateByName("two")], "Exit path");
    eqArray(paths[1], [], "no enter path");
  }

  public function testMoveDown():void {
    var m:SuperstateMachine = sampleMachine();

    var paths:Array = m.exitAndEnterPathsFromTo(m.stateByName("one"), m.stateByName("three"));

    eqArray(paths[0], [], "no exits");
    eqArray(paths[1], [m.stateByName("two"), m.stateByName("three")], "just enter all below");
  }

  public function testMoveUpAndDown():void {
    var m:SuperstateMachine = sampleMachine();

    var paths:Array = m.exitAndEnterPathsFromTo(m.stateByName("tres"), m.stateByName("three"));
    trace("PATH\n" + Helper.inspect(paths,  4));

    eqArray(paths[0], [m.stateByName("tres"), m.stateByName("dos"), m.stateByName("uno")], "exits");
    eqArray(paths[1], [m.stateByName("one"), m.stateByName("two"), m.stateByName("three")], "enters");
  }

  public function testMoveAround():void {
    var history:Array = [];
    var validateAndClearPath:Function = function(path:String, msg:String = ""):void {
      eq(history.join(","), path, "valid path" + (msg !== "" ? " - " : ""));
      while(history.length > 0) history.pop();
    };

    var m:SuperstateMachine = sampleMachine(history);

    validateAndClearPath("");

    m.to("three");
    eq(m.current, m.stateByName("three"));
    validateAndClearPath("in:1,in:2,in:3", "init path");

    m.to("another_three");
    eq(m.current, m.stateByName("another_three"));
    validateAndClearPath("out:3,in:3b", "same depth");

    m.to("one");
    validateAndClearPath("out:3b,out:2", "up to 1");

    m.to("uno");
    validateAndClearPath("out:1,in:a", "same root depth");
  }
}
}