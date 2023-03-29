module Utils
  module Calculations
    def comma_seperated_value(value)
      value = rounded_half_down_value(value.to_f)
      if value.to_i > 100000
        value = value.to_s.reverse.sub(/(\d{3})(?=\d)/, '\\1,').reverse
        temp1 = value.split(',')[0]
        temp2 = value.split(',')[1]
        temp1 = temp1.to_s.reverse.gsub(/(\d{2})(?=\d)/, '\\1,').reverse
        "#{temp1},#{temp2}"
      else
        value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end
    end

    def get_formatted_amount(value)
      return rounded_half_down_value(format('%g', value / 100000)) if value > 100000

      comma_seperated_value(value)
    end

    def rounded_half_down_value(input_value)
      return input_value.to_i if input_value.to_s.split('.').size == 1
      return input_value.to_i if input_value.to_s.split('.')[1].to_i.zero?

      BigDecimal(input_value.to_s).round(2, BigDecimal::ROUND_HALF_EVEN).to_f
    end

    def remove_comma_in_numbers(value)
      value.gsub(',', '').gsub(' ', '').gsub('₹', '')
    end

    def round_the_amount_to_lakhs(amount)
      if amount > 100000
        "₹#{(amount / 100000.to_f).round(2)} LAC"
      else
        "₹#{amount}"
      end
    end

    def calculate_prepayment_values(**values)
      values[:payment_date] = Date.today if values[:payment_date].nil?
      interest = rounded_half_down_value((values[:transaction_value].to_f * (1 + (($conf['yield'].to_f / 100) / 365))**(values[:payment_date] - values[:disbursement_date]).numerator) - values[:transaction_value].to_f)
      if values[:payment_value] - interest <= 0
        outstanding_value = rounded_half_down_value(values[:transaction_value] - values[:payment_value] + interest)
        interest = rounded_half_down_value(interest - values[:payment_value])
        return [outstanding_value, interest, 0, 0] # no pre-paymeny calculation if only interest is deducted on payment and no excess amount to refund
      end
      no_of_pre_paid_days = values[:tenor] - (values[:payment_date] - values[:disbursement_date]).numerator
      values[:payment_value] = values[:payment_value] - interest # pre-payments calculated for the principal alone
      amount_taken_for_prepayment = values[:payment_value] > values[:transaction_value] ? values[:transaction_value] : values[:payment_value] # if amount higher than principal, only limit upto pricipal is taken
      prepayment_charges = rounded_half_down_value((amount_taken_for_prepayment.to_f * (1 + (($conf['prepayment_charges'].to_f / 100) / 365))**no_of_pre_paid_days) - amount_taken_for_prepayment.to_f)
      outstanding_value = rounded_half_down_value(values[:transaction_value] - values[:payment_value] + prepayment_charges)
      if outstanding_value.zero? # no refund if outstanding is there
        [outstanding_value, 0, prepayment_charges, 0] # interest will be zero is pre-payment calculations happens
      else
        [0, 0, prepayment_charges, outstanding_value.abs] # outstanding value calculated(in negative) will be the refund amount
      end
    end

    def calculate_prepayment_value(**values)
      values[:payment_date] = Date.today if values[:payment_date].nil?
      rate = $conf['prepayment_charges'].to_f / 100
      no_of_pre_paid_days = values[:tenor] - (values[:payment_date] - values[:disbursement_date]).numerator
      charge = (values[:transaction_value].to_f * (1 + (rate / 365))**no_of_pre_paid_days) - values[:transaction_value].to_f
      rounded_half_down_value(charge)
    end

    def calculate_demanded_interest(transaction_value, diburse_date, payment_date)
      dibursal_date = Date.strptime(diburse_date, '%d-%b-%Y')
      date_of_payment = Date.strptime(payment_date, '%d-%b-%Y')
      no_of_days = 0
      return 0 if dibursal_date.month == date_of_payment.month

      temp_date = dibursal_date + 1
      loop do
        break unless Date.parse("1/#{temp_date.next_month.month}/#{temp_date.next_month.year}") <= date_of_payment

        total_days_in_month = Date.new(temp_date.strftime('%Y').to_i, temp_date.strftime('%m').to_i, -1).day
        no_of_days += if temp_date.month == dibursal_date.month
                        total_days_in_month - (temp_date.day - 1)
                      elsif temp_date.month != date_of_payment.month
                        total_days_in_month
                      else
                        date_of_payment.day
                      end
        temp_date = temp_date.next_month >= date_of_payment ? date_of_payment : temp_date.next_month
      end

      no_of_days += 1 if date_of_payment.day > 1
      (transaction_value.to_f * (1 + (($conf['yield'].to_f / 100) / 365))**no_of_days) - transaction_value.to_f
    end

    def calculate_outstanding_value(values)
      payment_date = values[:payment_date].nil? ? Date.today : values[:payment_date]
      transaction_value = values[:transaction_values][0]
      no_of_penal_days = 0
      tenor = if values[:tenor].nil?
                case values[:type]
                when 'frontend'
                  $conf['vendor_tenor']
                when 'rearend'
                  $conf['dealer_tenor']
                else
                  $conf['monthly_interest_tenor']
                end
              else
                values[:tenor]
              end
      due_date = Date.strptime(values[:due_date], '%d-%b-%Y')
      pricing = $conf['yield'].to_f / 100
      penal_charges = $conf['penal_charges'].to_f / 100

      no_of_penal_days = (payment_date - due_date).numerator.abs if payment_date > due_date
      tenor -= (due_date - payment_date).numerator if payment_date < due_date
      interest = if values[:type] == 'frontend'
                   (transaction_value.to_f * (1 + (pricing / 365))**no_of_penal_days) - transaction_value.to_f
                 else
                   (transaction_value.to_f * (1 + (pricing / 365))**(no_of_penal_days + tenor)) - transaction_value.to_f
                 end
      charges = (transaction_value.to_f * (1 + (penal_charges / 365))**no_of_penal_days) - transaction_value.to_f
      interest = rounded_half_down_value(interest)
      charges = rounded_half_down_value(charges)
      charges = 0 if charges.negative? # charges will be calculated in negative while Pre-payments.
      outstanding = rounded_half_down_value(transaction_value + interest + charges)
      [outstanding, interest, charges]
    end

    def calculate_additional_data_dd(hash)
      annualized_return = (30 / (hash['due_date'] - hash['desired_date']).numerator.to_f) * 12 * hash['discount'].to_i
      calculated_values = calculate_payable_value(
        {
          invoice_value: hash['invoice_value'],
          discount: hash['discount'].to_i,
          gst: $conf['gst'],
          tds: hash['tds']
        }
      )
      total_payable = calculated_values[0]
      gross_gain = total_payable * hash['discount'].to_i / 100
      actual_gain = annualized_return - hash['cost_of_fund']
      net_gain = gross_gain - (hash['cost_of_fund'] / 100.to_f * gross_gain)
      fee_charged = hash['fee'] / 100.to_f * net_gain
      net_fee = (fee_charged * 100) / gross_gain
      annualized_gain = actual_gain - net_fee
      {
        'ANNUALIZED RETURN' => "#{annualized_return}%",
        'GROSS GAIN' => "₹#{comma_seperated_value(gross_gain)}",
        'ACTUAL GAIN' => "#{actual_gain}%",
        'NET GAIN' => "₹#{comma_seperated_value(net_gain)}",
        'FEE CHARGED' => "₹#{comma_seperated_value(format('%g', fee_charged))}",
        'NET FEE' => "#{rounded_half_down_value(net_fee)}%",
        'ANNUALIZED GAIN' => "#{annualized_gain}%"
      }
    end

    # Dynamic discounting
    def calculate_payable_value(values)
      gst_amount = values[:invoice_value].to_f * values[:gst].to_f / 100
      discount_amount = values[:invoice_value].to_f * values[:discount].to_f / 100
      tds_amount = values[:invoice_value].to_f * values[:tds].to_f / 100
      total_payable = values[:invoice_value] + gst_amount - discount_amount - tds_amount
      [total_payable, gst_amount, discount_amount, tds_amount]
    end

    def compare_dates(dates, sort:)
      date_formats = dates.map { |date| Date.parse(date) }
      flag = true
      date_formats.each_with_index do |_k, i|
        break if i == date_formats.length - 1

        if sort == :asc
          flag &= date_formats[i] < date_formats[i + 1]
          p "#{date_formats[i]} < #{date_formats[i + 1]}" unless flag
        else
          flag &= date_formats[i] > date_formats[i + 1]
        end
      end
      flag
    end

    def compare_values(datas, sort)
      flag = true
      datas.each_with_index do |_k, i|
        break if i == datas.length - 1

        if sort.eql?('asc')
          flag &= datas[i] < datas[i + 1]
          p "#{datas[i]} < #{datas[i + 1]}" unless flag
        else
          flag &= datas[i] > datas[i + 1]
        end
      end
      flag
    end
  end
end
