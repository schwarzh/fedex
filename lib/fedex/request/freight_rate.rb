require 'fedex/request/base'

module Fedex
  module Request
    class FreightRate < Rate

      private

      # Add information for shipments
      def add_requested_shipment(xml)
        xml.RequestedShipment{
          xml.ServiceType service_type if service_type
          add_shipper(xml)
          add_recipient(xml)
          xml.ShippingChargesPayment{
            xml.PaymentType 'SENDER'
            xml.Payor{
              xml.ResponsibleParty{
                xml.AccountNumber @freight_account[:account_number]
              }
            }
          }
          add_freight_shipment_detail(xml)
        }
      end

      def add_freight_shipment_detail(xml)
        xml.FreightShipmentDetail{
          xml.AlternateBilling{
            xml.AccountNumber @freight_account[:account_number]
            xml.Address{
              xml.StreetLines @freight_account[:address]
              xml.City @freight_account[:city]
              xml.StateOrProvinceCode @freight_account[:state]
              xml.PostalCode @freight_account[:postal_code]
              xml.CountryCode @freight_account[:country_code]
            }
          }
          xml.Role 'SHIPPER'
          @packages.each do |package|
            xml.LineItems{
              xml.FreightClass 'CLASS_050'
              xml.Packaging 'PALLET'
              xml.Weight{
                xml.Units package[:weight][:units]
                xml.Value package[:weight][:value]
              }
            }
          end
        }
      end

    end
  end
end
