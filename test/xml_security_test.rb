require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))
require 'xml_security'
require 'timecop'

class XmlSecurityTest < Minitest::Test
  include XMLSecurity

  describe "XmlSecurity" do

    let(:decoded_response) { Base64.decode64(response_document_without_recipient) }

    before do
      @document = XMLSecurity::SignedDocument.new(decoded_response)
      @base64cert = @document.elements["//ds:X509Certificate"].text
    end

    it "should run validate without throwing NS related exceptions" do
      assert !@document.validate_signature(@base64cert, true)
    end

    it "should run validate with throwing NS related exceptions" do
      assert_raises(OneLogin::RubySaml::ValidationError) do
        @document.validate_signature(@base64cert, false)
      end
    end

    it "not raise an error when softly validating the document multiple times" do
      2.times { assert_equal @document.validate_signature(@base64cert, true), false }
    end

    it "not raise an error when softly validating the document and the X509Certificate is missing" do
      decoded_response.sub!(/<ds:X509Certificate>.*<\/ds:X509Certificate>/, "")
      document = XMLSecurity::SignedDocument.new(decoded_response)
      assert !document.validate_document("a fingerprint", true) # The fingerprint isn't relevant to this test
    end

    it "should raise Fingerprint mismatch" do
      exception = assert_raises(OneLogin::RubySaml::ValidationError) do
        @document.validate_document("no:fi:ng:er:pr:in:t", false)
      end
      assert_equal("Fingerprint mismatch", exception.message)
      assert @document.errors.include? "Fingerprint mismatch"
    end

    it "should raise Digest mismatch" do
      exception = assert_raises(OneLogin::RubySaml::ValidationError) do
        @document.validate_signature(@base64cert, false)
      end
      assert_equal("Digest mismatch", exception.message)
      assert @document.errors.include? "Digest mismatch"
    end

    it "should raise Key validation error" do
      decoded_response.sub!("<ds:DigestValue>pJQ7MS/ek4KRRWGmv/H43ReHYMs=</ds:DigestValue>",
                    "<ds:DigestValue>b9xsAXLsynugg3Wc1CI3kpWku+0=</ds:DigestValue>")
      document = XMLSecurity::SignedDocument.new(decoded_response)
      base64cert = document.elements["//ds:X509Certificate"].text
      exception = assert_raises(OneLogin::RubySaml::ValidationError) do
        document.validate_signature(base64cert, false)
      end
      assert_equal("Key validation error", exception.message)
      assert document.errors.include? "Key validation error"
    end

    it "correctly obtain the digest method with alternate namespace declaration" do
      document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_xmlns, false))
      base64cert = document.elements["//X509Certificate"].text
      assert document.validate_signature(base64cert, false)
    end

    it "raise validation error when the X509Certificate is missing" do
      decoded_response.sub!(/<ds:X509Certificate>.*<\/ds:X509Certificate>/, "")
      document = XMLSecurity::SignedDocument.new(decoded_response)
      exception = assert_raises(OneLogin::RubySaml::ValidationError) do
        document.validate_document("a fingerprint", false) # The fingerprint isn't relevant to this test
      end
      assert_equal("Certificate element missing in response (ds:X509Certificate)", exception.message)
    end
  end

  describe "Fingerprint Algorithms" do
    let(:response_fingerprint_test) { OneLogin::RubySaml::Response.new(fixture(:adfs_response_sha1, false)) }

    it "validate using SHA1" do
      sha1_fingerprint = "F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72"
      sha1_fingerprint_downcase = "f13c6b80905a030e6c913e5d15faddb016454872"

      assert response_fingerprint_test.document.validate_document(sha1_fingerprint)
      assert response_fingerprint_test.document.validate_document(sha1_fingerprint, true, :fingerprint_alg => XMLSecurity::Document::SHA1)

      assert response_fingerprint_test.document.validate_document(sha1_fingerprint_downcase)
      assert response_fingerprint_test.document.validate_document(sha1_fingerprint_downcase, true, :fingerprint_alg => XMLSecurity::Document::SHA1)
    end

    it "validate using SHA256" do
      sha256_fingerprint = "C4:C6:BD:41:EC:AD:57:97:CE:7B:7D:80:06:C3:E4:30:53:29:02:0B:DD:2D:47:02:9E:BD:85:AD:93:02:45:21"

      assert !response_fingerprint_test.document.validate_document(sha256_fingerprint)
      assert response_fingerprint_test.document.validate_document(sha256_fingerprint, true, :fingerprint_alg => XMLSecurity::Document::SHA256)
    end

    it "validate using SHA384" do
      sha384_fingerprint = "98:FE:17:90:31:E7:68:18:8A:65:4D:DA:F5:76:E2:09:97:BE:8B:E3:7E:AA:8D:63:64:7C:0C:38:23:9A:AC:A2:EC:CE:48:A6:74:4D:E0:4C:50:80:40:B4:8D:55:14:14"

      assert !response_fingerprint_test.document.validate_document(sha384_fingerprint)
      assert response_fingerprint_test.document.validate_document(sha384_fingerprint, true, :fingerprint_alg => XMLSecurity::Document::SHA384)
    end

    it "validate using SHA512" do
      sha512_fingerprint = "5A:AE:BA:D0:BA:9D:1E:25:05:01:1E:1A:C9:E9:FF:DB:ED:FA:6E:F7:52:EB:45:49:BD:DB:06:D8:A3:7E:CC:63:3A:04:A2:DD:DF:EE:61:05:D9:58:95:2A:77:17:30:4B:EB:4A:9F:48:4A:44:1C:D0:9E:0B:1E:04:77:FD:A3:D2"

      assert !response_fingerprint_test.document.validate_document(sha512_fingerprint)
      assert response_fingerprint_test.document.validate_document(sha512_fingerprint, true, :fingerprint_alg => XMLSecurity::Document::SHA512)
    end

  end

  describe "Signature Algorithms" do
    it "validate using SHA1" do
      @document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha1, false))
      assert @document.validate_document("F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72")
    end

    it "validate using SHA256" do
      @document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha256, false))
      assert @document.validate_document("28:74:9B:E8:1F:E8:10:9C:A8:7C:A9:C3:E3:C5:01:6C:92:1C:B4:BA")
    end

    it "validate using SHA384" do
      @document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha384, false))
      assert @document.validate_document("F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72")
    end

    it "validate using SHA512" do
      @document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha512, false))
      assert @document.validate_document("F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72")
    end
  end

  describe "XmlSecurity::SignedDocument" do

    describe "#extract_inclusive_namespaces" do
      it "support explicit namespace resolution for exclusive canonicalization" do
        response = fixture(:open_saml_response, false)
        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        assert_equal %w[ xs ], inclusive_namespaces
      end

      it "support implicit namespace resolution for exclusive canonicalization" do
        response = fixture(:no_signature_ns, false)
        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        assert_equal %w[ #default saml ds xs xsi ], inclusive_namespaces
      end

      it 'support inclusive canonicalization' do
        skip('test not yet implemented')
        response = OneLogin::RubySaml::Response.new(fixture("tdnf_response.xml"))
        response.stubs(:conditions).returns(nil)
        assert !response.is_valid?
        settings = OneLogin::RubySaml::Settings.new
        assert !response.is_valid?
        response.settings = settings
        assert !response.is_valid?
        settings.idp_cert_fingerprint = "e6 38 9a 20 b7 4f 13 db 6a bc b1 42 6a e7 52 1d d6 56 d4 1b".upcase.gsub(" ", ":")
        assert response.validate!
      end

      it "return an empty list when inclusive namespace element is missing" do
        response = fixture(:no_signature_ns, false)
        response.slice! %r{<InclusiveNamespaces xmlns="http://www.w3.org/2001/10/xml-exc-c14n#" PrefixList="#default saml ds xs xsi"/>}

        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        assert inclusive_namespaces.empty?
      end
    end

    describe "XMLSecurity::DSIG" do
      it "sign a AuthNRequest" do
        settings = OneLogin::RubySaml::Settings.new({
          :idp_sso_target_url => "https://idp.example.com/sso",
          :protocol_binding => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
          :issuer => "https://sp.example.com/saml2",
          :assertion_consumer_service_url => "https://sp.example.com/acs"
        })

        request = OneLogin::RubySaml::Authrequest.new.create_authentication_xml_doc(settings)
        request.sign_document(ruby_saml_key, ruby_saml_cert)

        # verify our signature
        signed_doc = XMLSecurity::SignedDocument.new(request.to_s)
        assert signed_doc.validate_document(ruby_saml_cert_fingerprint, false)
      end

      it "sign a LogoutRequest" do
        settings = OneLogin::RubySaml::Settings.new({
          :idp_slo_target_url => "https://idp.example.com/slo",
          :protocol_binding => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
          :issuer => "https://sp.example.com/saml2",
          :single_logout_service_url => "https://sp.example.com/sls"
        })

        request = OneLogin::RubySaml::Logoutrequest.new.create_logout_request_xml_doc(settings)
        request.sign_document(ruby_saml_key, ruby_saml_cert)

        # verify our signature
        signed_doc = XMLSecurity::SignedDocument.new(request.to_s)
        assert signed_doc.validate_document(ruby_saml_cert_fingerprint, false)
      end

      it "sign a LogoutResponse" do
        settings = OneLogin::RubySaml::Settings.new({
          :idp_slo_target_url => "https://idp.example.com/slo",
          :protocol_binding => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
          :issuer => "https://sp.example.com/saml2",
          :single_logout_service_url => "https://sp.example.com/sls"
        })

        response = OneLogin::RubySaml::SloLogoutresponse.new.create_logout_response_xml_doc(settings, 'request_id_example', "Custom Logout Message")
        response.sign_document(ruby_saml_key, ruby_saml_cert)

        # verify our signature
        signed_doc = XMLSecurity::SignedDocument.new(response.to_s)
        assert signed_doc.validate_document(ruby_saml_cert_fingerprint, false)
      end
    end

    describe "StarfieldTMS" do
      before do
        @response = OneLogin::RubySaml::Response.new(fixture(:starfield_response))
        @response.settings = OneLogin::RubySaml::Settings.new(
                                                          :idp_cert_fingerprint => "8D:BA:53:8E:A3:B6:F9:F1:69:6C:BB:D9:D8:BD:41:B3:AC:4F:9D:4D"
                                                          )
      end

      it "be able to validate a good response" do
        Timecop.freeze Time.parse('2012-11-28 17:55:00 UTC') do
          assert @response.validate!
        end
      end

      it "fail before response is valid" do
        Timecop.freeze Time.parse('2012-11-20 17:55:00 UTC') do
          assert ! @response.is_valid?
        end
      end

      it "fail after response expires" do
        Timecop.freeze Time.parse('2012-11-30 17:55:00 UTC') do
          assert ! @response.is_valid?
        end
      end
    end
  end
end
