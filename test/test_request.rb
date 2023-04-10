
require 'stringio'
require 'pork/auto'
require 'muack'
require 'battle-cats-rolls/request'

describe BattleCatsRolls::Request do
  include Muack::API

  def request
    @request ||= BattleCatsRolls::Request.new(env)
  end

  def env
    @env ||= {'rack.input' => StringIO.new}
  end

  describe '#parse_query' do
    would 'give an array if the same key is given multiple times' do
      expect(request.parse_query('t=0&t=1')).eq('t' => %w[0 1])
    end
  end

  describe '#params' do
    def env
      @env ||= super.merge('PATH_INFO' => '/abc/def')
    end

    would 'memoize the result' do
      object_id = request.params.object_id

      expect(request.params.object_id).eq object_id
    end
  end

  describe '#params_coercion' do
    would 'attempt to coerce again via #params_coercion_with_nil' do
      key = 'query'
      coercion = :to_i

      mock(request).params_coercion_with_nil(key, coercion){ nil }

      expect(request.params_coercion(key, coercion)).eq 0
    end
  end

  describe '#params_coercion_with_nil' do
    def env
      @env ||= super.merge('QUERY_STRING' => 'query=0&string=1&string=a')
    end

    would 'coerce the value with the coercion method' do
      expect(request.params_coercion_with_nil('query', :to_i)).eq 0
    end

    would 'give nil if the query does not exist' do
      expect(request.params_coercion_with_nil('none', :to_i)).eq nil
    end

    would 'give the last value of the same query' do
      expect(request.params_coercion_with_nil('string', :upcase)).eq 'A'
    end
  end

  describe '#params_coercion_true_or_nil' do
    def env
      @env ||= super.merge('QUERY_STRING' => 'zero=0&blank=%20&false=false')
    end

    would 'give true for 0' do
      expect(request.params_coercion_true_or_nil('zero')).eq true
    end

    would 'give nil for blank' do
      expect(request.params_coercion_true_or_nil('blank')).eq nil
    end

    would 'give true for false' do
      expect(request.params_coercion_true_or_nil('false')).eq true
    end

    would 'give nil for non-existing' do
      expect(request.params_coercion_true_or_nil('nothing')).eq nil
    end
  end
end
