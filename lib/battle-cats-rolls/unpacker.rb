# frozen_string_literal: true

require 'openssl'
require 'digest/md5'

module BattleCatsRolls
  class Unpacker < Struct.new(
    :ecb_key,
    :cbc_key, :cbc_iv,
    :cipher_mode, :bad_data, keyword_init: true)
    def self.for_list
      new(
        cipher_mode: :ecb, # list files are always encrypted in ecb
        ecb_key: Digest::MD5.hexdigest('pack')[0, 16])
    end

    def self.for_pack lang
      new(
        # pack files are encrypted in ecb earlier then changed to cbc
        cbc_key: [ENV["#{lang.upcase}_KEY"]].pack('H*'),
        cbc_iv: [ENV["#{lang.upcase}_IV"]].pack('H*'),
        ecb_key: Digest::MD5.hexdigest('battlecats')[0, 16])
    end

    def self.for_text
      TextUnpacker.new
    end

    def decrypt data, binary: false
      if cipher_mode
        safe_decrypt(data, binary: binary)
      else
        # we try cbc first because newer pack files are in cbc
        safe_decrypt(data, binary: binary, mode: :cbc) ||
          safe_decrypt(data, binary: binary, mode: :ecb)
      end
    end

    private

    def safe_decrypt data, binary: false, mode: cipher_mode
      self.bad_data = nil
      result = __send__("decrypt_aes_128_#{mode}", data)
      if binary
        result
      else
        result.force_encoding('UTF-8')

        if result.valid_encoding?
          self.cipher_mode = mode
          result
        end
      end
    rescue OpenSSL::Cipher::CipherError => e
      self.bad_data = e
      nil
    end

    def decrypt_aes_128_ecb data
      cipher = OpenSSL::Cipher.new('aes-128-ecb')
      cipher.decrypt
      cipher.key = ecb_key
      cipher.update(data) + cipher.final
    end

    def decrypt_aes_128_cbc data
      cipher = OpenSSL::Cipher.new('aes-128-cbc')
      cipher.decrypt
      cipher.key = cbc_key
      cipher.iv = cbc_iv
      cipher.update(data) + cipher.final
    end
  end

  class TextUnpacker
    def decrypt data, binary: false
      data.force_encoding('UTF-8')
    end

    def bad_data
    end
  end
end
