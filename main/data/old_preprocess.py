def preprocess(record: np.ndarray) -> np.ndarray:
    # truncate and expand record attributes
    with open('main/data/attributes.txt') as a, open('main/data/persistent_attributes.txt') as b:
        attributes, persist = a.read().split(','), b.read().split(',')
    preprocessed_record = np.empty(6, dtype=object)

    for i, attribute in enumerate(attributes):
        # enrich, truncate and translate CDR data
            
        # elif attribute == "Cust. EP IP" or attribute == "Prov. EP IP":
            #i p_data = extract_ip_data(record[i])
            # preprocessed_record.extend(ip_data)

        # if attribute == "IG Duration (min)":
        #     try:
        #         difference = float(record[i]) - float(record[i + 31])
        #         preprocessed_record[0] = difference
        #     except ValueError:
        #         print(record)

        # if attribute == "IG Setup Time":
        #     datetime = record[i].split(" ")
        #     time = [int(v) for v in datetime[1].split(":")]
        #     time_seconds = time[0] * 3600 + time[1] * 60 + time[2]
        #     preprocessed_record[0] = time_seconds
        #     day_seq = get_day_from_date(datetime[0])
        #     # preprocessed_record[2] = day_seq

        if attribute == "Calling Number":
            num = record[i] 

            if num == "anonymous":
                preprocessed_record[0] = (0)
            else:
                # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                    p_int = re.sub("[ +-]", "", p_int)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record[0] = (p_int + "0" * (13 - len(p_int)))[:13]

        elif attribute == "Called Number":
            num = record[i]

            if num == "anonymous":
                preprocessed_record[1] = (0)
                preprocessed_record[2] = ("N/a")
            else:
                    # convert number to international format
                try:
                    p = phonenumbers.parse("+" + num, None)
                    p_int = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
                    p_int = re.sub("[ +-]", "", p_int)
                except phonenumbers.phonenumberutil.NumberParseException:
                    p_int = num
                preprocessed_record[1] = (p_int + "0" * (13 - len(p_int)))[:13]
                # get destination from number
                # preprocessed_record[0] = (get_destination(str(p_int)[1:]))
                # called number destination contained in new CDR
                preprocessed_record[2] = (record[i + 1])

        # elif attribute == "IG Packet Received":
        #     try:
        #         difference = float(record[i - 40]) - float(record[i])
        #         preprocessed_record[6] = (difference)
        #     except ValueError:
        #         print(record)

        # elif attribute == "EG Packet Received":
        #     try:
        #         difference = float(record[i + 42]) - float(record[i])
        #         preprocessed_record[7] = (difference)
        #     except ValueError:
        #         print(record)

        # elif attribute == "Prefix":
        #     preprocessed_record[6] = (record[i] + "0" * (7 - len(record[i])))[:7]

        elif attribute in persist:
            j = persist.index(attribute)
            preprocessed_record[j + 3] = record[i]
    return preprocessed_record