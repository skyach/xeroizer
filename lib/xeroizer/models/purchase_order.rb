require "xeroizer/models/attachment"

module Xeroizer
  module Record

    class PurchaseOrderModel < BaseModel
      # To create a new invoice, use the folowing
      # $xero_client.Invoice.build(type: 'ACCREC', ..., contact: {name: 'Foo Bar'},...)
      # Note that we are not making an api request to xero just to get the contact

      set_permissions :read, :write, :update


    end

    class PurchaseOrder < Base

      PURCHASE_ORDER_STATUS = {
          'AUTHORISED' =>       'AUTHORISED',
          'BILLED' =>           'BILLED',
          'DELETED' =>          'DELETED',
          'DRAFT' =>            'DRAFT',
          'SUBMITTED' =>        'SUBMITTED'
      } unless defined?(PURCHASE_ORDER_STATUS)


      set_primary_key :purchase_order_id
      set_possible_primary_keys :purchase_order_id, :purchase_order_number
      list_contains_summary_only true

      guid         :purchase_order_id
      string       :purchase_order_number
      string       :reference
      string       :line_amount_types
      guid         :branding_theme_id
      date         :date
      date         :delivery_date
      date         :expected_arrival_date
      string       :status
      string       :line_amount_types
      decimal      :sub_total, :calculated => true
      decimal      :total_tax, :calculated => true
      decimal      :total, :calculated => true
      decimal      :total_discount
      boolean      :has_attachments
      string       :reference
      string       :currency_code
      decimal      :currency_rate
      boolean      :sent_to_contact
      string       :delivery_address
      string       :attention_to
      string       :telephone
      string       :delivery_instructions


      belongs_to   :contact
      has_many     :line_items, :complete_on_page => true



      public

      # Access the contact name without forcing a download of
      # an incomplete, summary invoice.
      def contact_name
        attributes[:contact] && attributes[:contact][:name]
      end

      # Access the contact ID without forcing a download of an
      # incomplete, summary invoice.
      def contact_id
        attributes[:contact] && attributes[:contact][:contact_id]
      end

      # Helper method to check if the invoice has been approved.
      def approved?
        [ 'AUTHORISED', 'BILLED'].include? status
      end

      def sub_total=(sub_total)
        @sub_total_is_set = true
        attributes[:sub_total] = sub_total
      end

      def total_tax=(total_tax)
        @total_tax_is_set = true
        attributes[:total_tax] = total_tax
      end

      def total=(total)
        @total_is_set = true
        attributes[:total] = total
      end

      # Calculate sub_total from line_items.
      def sub_total(always_summary = false)
        if !@sub_total_is_set && not_summary_or_loaded_record(always_summary)
          sum = (line_items || []).inject(BigDecimal.new('0')) { | sum, line_item | sum + line_item.line_amount }

          # If the default amount types are inclusive of 'tax' then remove the tax amount from this sub-total.
          sum -= total_tax if line_amount_types == 'Inclusive'
          sum
        else
          attributes[:sub_total]
        end
      end

      # Calculate total_tax from line_items.
      def total_tax(always_summary = false)
        if !@total_tax_is_set && not_summary_or_loaded_record(always_summary)
          (line_items || []).inject(BigDecimal.new('0')) { | sum, line_item | sum + line_item.tax_amount }
        else
          attributes[:total_tax]
        end
      end

      # Calculate the total from line_items.
      def total(always_summary = false)
        if !@total_is_set && not_summary_or_loaded_record(always_summary)
          sub_total + total_tax
        else
          attributes[:total]
        end
      end

      def not_summary_or_loaded_record(always_summary)
        !always_summary && loaded_record?
      end

      def loaded_record?
        new_record? ||
            (!new_record? && line_items && line_items.size > 0)
      end

      # Delete an approved invoice with no payments.
      def delete!
        change_status!('DELETED')
      end

      # Approve a draft invoice
      def approve!
        change_status!('AUTHORISED')
      end

      protected

      def change_status!(new_status)
        raise CannotChangePurchaseOrderStatus.new(self, new_status)
        self.status = new_status
        self.save
      end

    end

  end
end
