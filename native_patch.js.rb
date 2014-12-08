''||eval('begin=undefined');_=nil
=begin
;eval(Opal.compile('=begin\n'+heredoc(function(){/*
=end

# https://github.com/opal/opal/issues/661
class Array

  def to_n
    %x{
      var result = [];
      var changed = false;

      for (var i = 0, length = self.length; i < length; i++) {
        var obj = self[i];
        var converted = #{Native.convert(`obj`)};

        if (obj !== converted) {
          changed = true;
        }
        result.push(converted);
      }

      if (changed) {
        return result;
      }

      return self;
    }
  end

end

#*/})));