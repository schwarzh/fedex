require 'fedex/request/base'

module Fedex
  module Request
    class Rate < Base
      # Sends post request to Fedex web service and parse the response, a Rate object is created if the response is successful
      def process_request
        puts build_xml if @debug == true
        api_response = self.class.post(api_url, :body => build_xml)
        puts api_response if @debug == true
        response = parse_response(api_response)
        if success?(response)
          rate_reply_details = response[:rate_reply][:rate_reply_details] || []
          rate_reply_details = [rate_reply_details] if rate_reply_details.is_a?(Hash)

          rate_reply_details.map do |rate_reply|
            if @shipping_options[:rate_request_type] == "LIST"
              rate_details = [rate_reply[:rated_shipment_details]].flatten.second[:shipment_rate_detail]
            else
              rate_details = [rate_reply[:rated_shipment_details]].flatten.first[:shipment_rate_detail]
            end

            is_saturday_delivery = rate_reply[:applied_options] && rate_reply[:applied_options] == 'SATURDAY_DELIVERY'
            service_type = is_saturday_delivery ? "#{rate_reply[:service_type]}_SATURDAY_DELIVERY" : rate_reply[:service_type]
            rate_details.merge!(service_type: service_type)
            rate_details.merge!(delivery_timestamp: rate_reply[:delivery_timestamp])
            rate_details.merge!(transit_time: rate_reply[:transit_time])
            rate_details.merge!(special_rating_applied: rate_reply[:special_rating_applied])
            Fedex::Rate.new(rate_details)
          end
        else
          error_message = if response[:rate_reply]
            [response[:rate_reply][:notifications]].flatten.first[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
          end rescue $1

          raise RateError, error_message || response[:fault][:detail][:desc]
        end
      end

      private

      # Add information for shipments
      def add_requested_shipment(xml)
        xml.RequestedShipment{
          xml.ShipTimestamp @shipping_options[:ship_timestamp] if @shipping_options[:ship_timestamp]
          xml.DropoffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
          xml.ServiceType service_type if service_type
          xml.PackagingType @shipping_options[:packaging_type] ||= "YOUR_PACKAGING"
          add_shipper(xml)
          add_recipient(xml)
          #add_shipping_charges_payment(xml)
          add_shipment_special_service_type(xml)
          add_customs_clearance(xml) if @customs_clearance_detail
          xml.RateRequestTypes @shipping_options[:rate_request_type] if @shipping_options[:rate_request_type] && @shipping_options[:rate_request_type] == "LIST"
          #xml.RateRequestTypes "LIST"
          add_smart_post(xml) if @smart_post
          #xml.EdtRequestType 'ALL'
          add_packages(xml)
        }
      end

      # Add transite time options
      def add_transit_time(xml)
        xml.ReturnTransitAndCommit true
      end

      # Returns saturday delivery shipping options when available
      def add_saturday_delivery(xml)
        xml.VariableOptions('SATURDAY_DELIVERY') if @shipping_options[:saturday_delivery]
      end

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/rate/v#{service[:version]}"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.RateRequest(:xmlns => ns){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)          
            add_transit_time(xml)
            add_saturday_delivery(xml)  
            add_requested_shipment(xml)
          }
        end
        builder.doc.root.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def service
        { :id => 'crs', :version => Fedex::API_VERSION }
      end

      # Successful request
      def success?(response)
        response[:rate_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:rate_reply][:highest_severity])
      end

    end
  end
end
