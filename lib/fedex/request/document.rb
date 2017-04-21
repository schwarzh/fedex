require 'fedex/request/shipment'
require 'fedex/document'

module Fedex
  module Request
    class Document < Shipment

      def initialize(credentials, options={})
        super(credentials, options)

        @shipping_document = options[:shipping_document]
        @filenames = options.fetch(:filenames) { {} }
      end

      def add_custom_components(xml)
        super
        if @shipping_document == "COMMERCIAL_INVOICE"
          add_commercial_invoice(xml)
        else
          add_shipping_document(xml) if @shipping_document
        end
      end

      private

      # Add shipping document specification
      def add_shipping_document(xml)
        xml.ShippingDocumentSpecification{
          Array(@shipping_document[:shipping_document_types]).each do |type|
            xml.ShippingDocumentTypes type
          end
          hash_to_xml(xml, @shipping_document.reject{ |k| k == :shipping_document_types})
        }
      end

      # If additional types of documents are needed, individual functions
      # can go here. Basically, these are hardcoded required values, and
      # shouldn't be in Blackbox core code just because the fedex gem and
      # API are quirky and bad
      #  - ajb, 21 Apr 2017
      def add_commercial_invoice(xml)
        xml.ShippingDocumentSpecification{
          xml.ShippingDocumentTypes "COMMERCIAL_INVOICE"
          xml.CommercialInvoiceDetail {
            xml.Format {
              xml.ImageType "PDF"
              xml.StockType "PAPER_LETTER"
            }
          }
        }
      end

      def success_response(api_response, response)
        super

        shipment_documents = response.merge!({
          :filenames => @filenames
        })

        Fedex::Document.new shipment_documents
      end

    end
  end
end
